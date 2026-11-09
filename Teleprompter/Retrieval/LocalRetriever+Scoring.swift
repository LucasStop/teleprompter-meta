import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

// MARK: - Consultas Internas e Pontuação

extension LocalRetriever {
    struct ScoredCandidate {
        let id: Int64
        let kind: IndexedChunk.Kind
        let sourcePath: String
        let text: String
        let score: Double
    }

    func fetchLexicalScores(ftsQuery: String, queryTokens: [String]) -> [Int64: Double] {
        var scores: [Int64: Double] = [:]
        let sql = "SELECT rowid, -bm25(chunks_fts), search_text FROM chunks_fts WHERE chunks_fts MATCH ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &stmt, nil) == SQLITE_OK else { return scores }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, ftsQuery, -1, sqliteTransient)
        while sqlite3_step(stmt) == SQLITE_ROW {
            let rowID = sqlite3_column_int64(stmt, 0)
            let rawScore = max(0.0, sqlite3_column_double(stmt, 1))
            let bm25Normalized = rawScore / (rawScore + 1.0)

            var overlapScore = 0.0
            if !queryTokens.isEmpty, let textCStr = sqlite3_column_text(stmt, 2) {
                let searchText = String(cString: textCStr)
                let matchedCount = queryTokens.filter { token in
                    searchText.localizedCaseInsensitiveContains(token)
                }.count
                overlapScore = Double(matchedCount) / Double(queryTokens.count)
            }

            let finalLexical = max(bm25Normalized, overlapScore * 0.6)
            scores[rowID] = finalLexical
        }
        return scores
    }

    func fetchAndScoreChunks(
        kindFilter: String,
        lexicalScores: [Int64: Double],
        queryVector: [Float]?
    ) -> [ScoredCandidate] {
        var candidates: [ScoredCandidate] = []
        let sql = "SELECT id, kind, source_path, text, embedding FROM chunks WHERE \(kindFilter);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &stmt, nil) == SQLITE_OK else { return candidates }
        defer { sqlite3_finalize(stmt) }

        while sqlite3_step(stmt) == SQLITE_ROW {
            let rowID = sqlite3_column_int64(stmt, 0)
            guard let kindStr = sqlite3_column_text(stmt, 1).map({ String(cString: $0) }),
                  let kind = IndexedChunk.Kind(rawValue: kindStr),
                  let sourceStr = sqlite3_column_text(stmt, 2).map({ String(cString: $0) }),
                  let textStr = sqlite3_column_text(stmt, 3).map({ String(cString: $0) }) else {
                continue
            }

            let lexicalScore = lexicalScores[rowID] ?? 0.0

            let finalScore: Double
            if let queryVector {
                let byteCount = sqlite3_column_bytes(stmt, 4)
                let semanticScore: Double
                if byteCount > 0, let blobBytes = sqlite3_column_blob(stmt, 4) {
                    let floatCount = Int(byteCount) / MemoryLayout<Float>.stride
                    let chunkVector = blobBytes.bindMemory(to: Float.self, capacity: floatCount)
                    let vec = Array(UnsafeBufferPointer(start: chunkVector, count: floatCount))
                    semanticScore = cosineSimilarity(queryVector, vec)
                } else {
                    semanticScore = 0.0
                }
                finalScore = 0.5 * lexicalScore + 0.5 * semanticScore
            } else {
                finalScore = lexicalScore
            }

            candidates.append(ScoredCandidate(
                id: rowID,
                kind: kind,
                sourcePath: sourceStr,
                text: textStr,
                score: finalScore
            ))
        }

        return candidates.sorted { $0.score > $1.score }
    }

    func cosineSimilarity(_ lhs: [Float], _ rhs: [Float]) -> Double {
        guard lhs.count == rhs.count, !lhs.isEmpty else { return 0.0 }
        var dot: Float = 0
        var normA: Float = 0
        var normB: Float = 0
        for index in lhs.indices {
            dot += lhs[index] * rhs[index]
            normA += lhs[index] * lhs[index]
            normB += rhs[index] * rhs[index]
        }
        let denom = sqrt(normA) * sqrt(normB)
        guard denom > 0 else { return 0.0 }
        return Double(max(0.0, min(1.0, dot / denom)))
    }

    func extractTokens(from text: String) -> [String] {
        let rawTokens = text
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }

        let contentTokens = rawTokens.filter { token in
            let normalized = token.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            return !portugueseStopWords.contains(normalized)
        }

        return contentTokens.isEmpty ? rawTokens : contentTokens
    }

    func execute(_ sql: String) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(database, sql, nil, nil, &errorMessage) != SQLITE_OK {
            let message = errorMessage.map { String(cString: $0) } ?? "Erro desconhecido"
            sqlite3_free(errorMessage)
            throw LocalRetrieverError.databaseExecutionFailed(message)
        }
    }
}
