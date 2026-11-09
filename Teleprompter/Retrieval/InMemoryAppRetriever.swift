import Foundation

/// Recuperador em memória com suporte a projetos e dados mockados para testes e previews.
final class InMemoryAppRetriever: Retriever, MaterialIndexable, @unchecked Sendable {
    private let lock = NSLock()
    private var projectChunks: [String: [IndexedChunk]] = [:]
    var settingsStore: (any SettingsStore)?

    init(settingsStore: (any SettingsStore)? = nil) {
        self.settingsStore = settingsStore
    }

    private var activeProjectId: String {
        settingsStore?.load().activeProjectId ?? Project.defaultId
    }

    private func activeProjectChunks() -> [IndexedChunk] {
        lock.withLock {
            let proj = activeProjectId
            return projectChunks[proj] ?? []
        }
    }

    func stats(for projectId: String) -> (filesCount: Int, chunksCount: Int) {
        lock.withLock {
            let chunks = projectChunks[projectId] ?? []
            if chunks.isEmpty && (projectId == "cursos" || projectId == Project.defaultId) {
                if projectId == "cursos" {
                    return (123, 1910)
                } else {
                    return (143, 1265)
                }
            }
            let uniqueFiles = Set(chunks.map(\.source.path)).count
            return (uniqueFiles, chunks.count)
        }
    }

    func listSources(for projectId: String) -> [MaterialSource] {
        lock.withLock {
            let chunks = projectChunks[projectId] ?? []
            let grouped = Dictionary(grouping: chunks, by: { $0.source.path })
            return grouped.map { path, fileChunks in
                let kind = fileChunks.first?.kind ?? .document
                let name = URL(fileURLWithPath: path).lastPathComponent
                let count = fileChunks.count
                return MaterialSource(
                    name: name.isEmpty ? path : name,
                    path: path,
                    kind: kind,
                    chunkCount: count,
                    subtitle: kind == .qa ? "\(count) perguntas" : "Importado"
                )
            }.sorted { $0.name < $1.name }
        }
    }

    func listActiveSources() -> [MaterialSource] {
        listSources(for: activeProjectId)
    }

    func deleteIndex(for projectId: String) throws {
        lock.withLock {
            _ = projectChunks.removeValue(forKey: projectId)
        }
    }

    func index(_ items: [IndexedChunk]) throws {
        lock.withLock {
            let proj = activeProjectId
            var existing = projectChunks[proj] ?? []
            existing.append(contentsOf: items)
            projectChunks[proj] = existing
        }
    }

    func removeSource(_ path: String) throws {
        lock.withLock {
            let proj = activeProjectId
            projectChunks[proj]?.removeAll { $0.source.path == path }
        }
    }

    func retrieve(_ question: String) async throws -> Retrieval {
        let proj = activeProjectId
        let chunks = activeProjectChunks()
        let lower = question.lowercased()

        if !chunks.isEmpty {
            if let qaChunk = chunks.first(where: {
                $0.kind == .qa && ($0.question?.lowercased().contains(lower) == true
                    || lower.contains($0.question?.lowercased() ?? ""))
            }) {
                return Retrieval(qaNote: Chunk(text: qaChunk.text, source: qaChunk.source), chunks: [])
            }
            let matching = chunks.filter {
                $0.text.lowercased().contains(lower) || lower.contains($0.text.lowercased())
            }
            if !matching.isEmpty {
                return Retrieval(qaNote: nil, chunks: matching.map { Chunk(text: $0.text, source: $0.source) })
            }
            return Retrieval(qaNote: nil, chunks: [])
        }

        if proj == Project.defaultId || proj.isEmpty || proj == "cursos" {
            if lower.contains("swift") || lower.contains("flutter") {
                let note = Chunk(
                    text: "• DAT SDK só tem módulos Swift\n• Menor latência de áudio\n• Acesso direto ao SpeechAnalyzer",
                    source: SourceRef(path: "qa/stack.md")
                )
                return Retrieval(qaNote: note, chunks: [])
            }

            if lower.contains("problema") || lower.contains("resolve") {
                let chunk = Chunk(
                    text: "• Resposta rápida na banca\n• Sem olhar anotações",
                    source: SourceRef(path: "README.md")
                )
                return Retrieval(qaNote: nil, chunks: [chunk])
            }

            if lower.contains("busca") {
                let chunk = Chunk(
                    text: "Busca híbrida com BM25 e embeddings locais no dispositivo.",
                    source: SourceRef(path: "docs/ADR-0001.md")
                )
                return Retrieval(qaNote: nil, chunks: [chunk])
            }
        }

        return Retrieval(qaNote: nil, chunks: [])
    }
}
