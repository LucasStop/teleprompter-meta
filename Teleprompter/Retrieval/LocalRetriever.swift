import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

let portugueseStopWords: Set<String> = [
    "a", "ao", "aos", "as", "ate", "com", "como", "da", "das", "de", "do", "dos",
    "e", "em", "entre", "era", "essa", "esse", "esta", "estao", "eu", "foi", "foram",
    "isso", "ja", "mais", "mas", "me", "mesmo", "meu", "muito", "na", "nas", "nao",
    "no", "nos", "num", "o", "os", "ou", "para", "pela", "pelas", "pelo", "pelos",
    "por", "qual", "quando", "que", "quem", "se", "sem", "ser", "seu", "seus", "so",
    "sua", "suas", "tambem", "tem", "ter", "tinha", "um", "uma", "voce"
]

enum LocalRetrieverError: Error, LocalizedError, Sendable {
    case databaseOpenFailed(Int32)
    case databaseExecutionFailed(String)

    var errorDescription: String? {
        switch self {
        case .databaseOpenFailed(let code):
            return "Falha ao abrir banco de dados SQLite (código: \(code))."
        case .databaseExecutionFailed(let message):
            return "Erro ao executar operação no SQLite: \(message)."
        }
    }
}

/// Recuperador local de material sobre SQLite3 com FTS5 e suporte opcional a embeddings.
/// Segue RAG fechado (ADR-0004 e ADR-0009): prioriza Q&A e devolve vazio se nada atingir o limiar.
final class LocalRetriever: Retriever, @unchecked Sendable {
    let database: OpaquePointer
    private let writeQueue = DispatchQueue(label: "br.com.lucasstop.teleprompter.retrieval.write")
    private let embedder: (any Embedder)?

    /// Limiar mínimo para match em notas de Q&A (padrão: 0.40).
    let qaThreshold: Double
    /// Limiar mínimo para trechos de documentos e código (padrão: 0.25).
    let chunkThreshold: Double
    /// Número máximo de trechos retornados quando não há match no Q&A (padrão: 3).
    let topK: Int

    init(
        databaseURL: URL,
        embedder: (any Embedder)? = nil,
        qaThreshold: Double = 0.40,
        chunkThreshold: Double = 0.25,
        topK: Int = 3
    ) throws {
        self.embedder = embedder
        self.qaThreshold = qaThreshold
        self.chunkThreshold = chunkThreshold
        self.topK = max(1, topK)

        let fileManager = FileManager.default
        let directoryURL = databaseURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        var dbPointer: OpaquePointer?
        let openResult = sqlite3_open(databaseURL.path, &dbPointer)
        guard openResult == SQLITE_OK, let dbPointer else {
            throw LocalRetrieverError.databaseOpenFailed(openResult)
        }
        self.database = dbPointer

        try createTables()
    }

    deinit {
        sqlite3_close(database)
    }

    private func createTables() throws {
        let sql = """
        PRAGMA journal_mode = WAL;
        PRAGMA synchronous = NORMAL;

        CREATE TABLE IF NOT EXISTS chunks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            kind TEXT NOT NULL,
            source_path TEXT NOT NULL,
            text TEXT NOT NULL,
            search_text TEXT NOT NULL,
            embedding BLOB
        );

        CREATE INDEX IF NOT EXISTS idx_chunks_source ON chunks(source_path);

        CREATE VIRTUAL TABLE IF NOT EXISTS chunks_fts USING fts5(
            search_text,
            tokenize='unicode61 remove_diacritics 2'
        );
        """

        var errorMessage: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(database, sql, nil, nil, &errorMessage) != SQLITE_OK {
            let message = errorMessage.map { String(cString: $0) } ?? "Erro desconhecido"
            sqlite3_free(errorMessage)
            throw LocalRetrieverError.databaseExecutionFailed(message)
        }
    }

    // MARK: - Indexação

    func index(_ items: [IndexedChunk]) throws {
        try writeQueue.sync {
            try performIndex(items)
        }
    }

    private func performIndex(_ items: [IndexedChunk]) throws {
        guard !items.isEmpty else { return }

        try execute("BEGIN IMMEDIATE TRANSACTION;")
        do {
            let insertChunkStmt = try prepareInsertChunkStatement()
            defer { sqlite3_finalize(insertChunkStmt) }

            let insertFtsStmt = try prepareInsertFtsStatement()
            defer { sqlite3_finalize(insertFtsStmt) }

            for item in items {
                try insertSingleItem(item, chunkStmt: insertChunkStmt, ftsStmt: insertFtsStmt)
            }
            try execute("COMMIT;")
        } catch {
            try execute("ROLLBACK;")
            throw error
        }
    }

    private func prepareInsertChunkStatement() throws -> OpaquePointer {
        let sql = "INSERT INTO chunks (kind, source_path, text, search_text, embedding) VALUES (?, ?, ?, ?, ?);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            let message = String(cString: sqlite3_errmsg(database))
            throw LocalRetrieverError.databaseExecutionFailed(message)
        }
        return stmt
    }

    private func prepareInsertFtsStatement() throws -> OpaquePointer {
        let sql = "INSERT INTO chunks_fts (rowid, search_text) VALUES (?, ?);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            let message = String(cString: sqlite3_errmsg(database))
            throw LocalRetrieverError.databaseExecutionFailed(message)
        }
        return stmt
    }

    private func insertSingleItem(_ item: IndexedChunk, chunkStmt: OpaquePointer, ftsStmt: OpaquePointer) throws {
        let searchText = item.kind == .qa ? (item.question ?? item.text) : item.text

        sqlite3_reset(chunkStmt)
        sqlite3_bind_text(chunkStmt, 1, item.kind.rawValue, -1, sqliteTransient)
        sqlite3_bind_text(chunkStmt, 2, item.source.path, -1, sqliteTransient)
        sqlite3_bind_text(chunkStmt, 3, item.text, -1, sqliteTransient)
        sqlite3_bind_text(chunkStmt, 4, searchText, -1, sqliteTransient)

        if let embedder {
            var embedding = embedder.embed(searchText)
            let byteCount = embedding.count * MemoryLayout<Float>.stride
            sqlite3_bind_blob(chunkStmt, 5, &embedding, Int32(byteCount), sqliteTransient)
        } else {
            sqlite3_bind_null(chunkStmt, 5)
        }

        guard sqlite3_step(chunkStmt) == SQLITE_DONE else {
            let message = String(cString: sqlite3_errmsg(database))
            throw LocalRetrieverError.databaseExecutionFailed(message)
        }

        let rowID = sqlite3_last_insert_rowid(database)

        sqlite3_reset(ftsStmt)
        sqlite3_bind_int64(ftsStmt, 1, rowID)
        sqlite3_bind_text(ftsStmt, 2, searchText, -1, sqliteTransient)

        guard sqlite3_step(ftsStmt) == SQLITE_DONE else {
            let message = String(cString: sqlite3_errmsg(database))
            throw LocalRetrieverError.databaseExecutionFailed(message)
        }
    }

    // MARK: - Remoção

    func removeSource(_ source: SourceRef) throws {
        try removeSource(source.path)
    }

    func removeSource(_ path: String) throws {
        try writeQueue.sync {
            try performRemoveSource(path)
        }
    }

    private func performRemoveSource(_ path: String) throws {
        try execute("BEGIN IMMEDIATE TRANSACTION;")

        let deleteFtsSQL = "DELETE FROM chunks_fts WHERE rowid IN (SELECT id FROM chunks WHERE source_path = ?);"
        var deleteFtsStmt: OpaquePointer?
        if sqlite3_prepare_v2(database, deleteFtsSQL, -1, &deleteFtsStmt, nil) == SQLITE_OK {
            sqlite3_bind_text(deleteFtsStmt, 1, path, -1, sqliteTransient)
            sqlite3_step(deleteFtsStmt)
            sqlite3_finalize(deleteFtsStmt)
        }

        let deleteChunksSQL = "DELETE FROM chunks WHERE source_path = ?;"
        var deleteChunksStmt: OpaquePointer?
        if sqlite3_prepare_v2(database, deleteChunksSQL, -1, &deleteChunksStmt, nil) == SQLITE_OK {
            sqlite3_bind_text(deleteChunksStmt, 1, path, -1, sqliteTransient)
            sqlite3_step(deleteChunksStmt)
            sqlite3_finalize(deleteChunksStmt)
        }

        try execute("COMMIT;")
    }

    // MARK: - Recuperação

    func retrieve(_ question: String) async throws -> Retrieval {
        let tokens = extractTokens(from: question)
        guard !tokens.isEmpty else {
            return Retrieval(qaNote: nil, chunks: [])
        }

        return writeQueue.sync {
            let ftsQuery = tokens.map { "\"\($0)\"" }.joined(separator: " OR ")
            let lexicalScores = fetchLexicalScores(ftsQuery: ftsQuery, queryTokens: tokens)
            let queryVector = embedder?.embed(question)

            let scoredQA = fetchAndScoreChunks(
                kindFilter: "kind = 'qa'",
                lexicalScores: lexicalScores,
                queryVector: queryVector
            )

            if let bestQA = scoredQA.first, bestQA.score >= qaThreshold {
                let noteChunk = Chunk(text: bestQA.text, source: SourceRef(path: bestQA.sourcePath))
                return Retrieval(qaNote: noteChunk, chunks: [])
            }

            let scoredChunks = fetchAndScoreChunks(
                kindFilter: "kind IN ('document', 'code')",
                lexicalScores: lexicalScores,
                queryVector: queryVector
            )

            let qualifyingChunks = scoredChunks
                .filter { $0.score >= chunkThreshold }
                .prefix(topK)
                .map { Chunk(text: $0.text, source: SourceRef(path: $0.sourcePath)) }

            return Retrieval(qaNote: nil, chunks: Array(qualifyingChunks))
        }
    }

    // MARK: - Estatísticas e Fontes

    func stats() -> (filesCount: Int, chunksCount: Int) {
        writeQueue.sync {
            var filesCount = 0
            var chunksCount = 0
            let sql = "SELECT COUNT(DISTINCT source_path), COUNT(*) FROM chunks;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(database, sql, -1, &stmt, nil) == SQLITE_OK, let stmt {
                if sqlite3_step(stmt) == SQLITE_ROW {
                    filesCount = Int(sqlite3_column_int(stmt, 0))
                    chunksCount = Int(sqlite3_column_int(stmt, 1))
                }
                sqlite3_finalize(stmt)
            }
            return (filesCount, chunksCount)
        }
    }

    func listSources() -> [MaterialSource] {
        writeQueue.sync {
            let sql = "SELECT source_path, kind, COUNT(*) FROM chunks GROUP BY source_path, kind ORDER BY source_path ASC;"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(database, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { return [] }
            defer { sqlite3_finalize(stmt) }

            var sources: [MaterialSource] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                guard let pathStr = sqlite3_column_text(stmt, 0).map({ String(cString: $0) }),
                      let kindStr = sqlite3_column_text(stmt, 1).map({ String(cString: $0) }),
                      let kind = IndexedChunk.Kind(rawValue: kindStr) else { continue }
                let chunkCount = Int(sqlite3_column_int(stmt, 2))
                let name = URL(fileURLWithPath: pathStr).lastPathComponent
                let subtitle = kind == .qa ? "\(chunkCount) perguntas" : "Importado"
                sources.append(MaterialSource(
                    name: name.isEmpty ? pathStr : name,
                    path: pathStr,
                    kind: kind,
                    chunkCount: chunkCount,
                    subtitle: subtitle
                ))
            }
            return sources
        }
    }
}
