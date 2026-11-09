import Foundation

/// Recuperador de produção sobre SQLite que responde à atualização de limiares do SettingsStore
/// e atua como índice isolado por projeto para o MaterialViewModel (ADR-0010).
final class ProductionAppRetriever: Retriever, MaterialIndexable, @unchecked Sendable {
    let directoryURL: URL
    private let settingsStore: any SettingsStore
    private let lock = NSLock()
    private var cache: [String: (retriever: LocalRetriever, settings: Settings)] = [:]

    init(directoryURL: URL, settingsStore: any SettingsStore) {
        self.directoryURL = directoryURL
        self.settingsStore = settingsStore
    }

    convenience init(databaseURL: URL, settingsStore: any SettingsStore) {
        let dir = databaseURL.hasDirectoryPath ? databaseURL : databaseURL.deletingLastPathComponent()
        self.init(directoryURL: dir, settingsStore: settingsStore)
    }

    func databaseURL(for projectId: String) -> URL {
        if projectId == Project.defaultId || projectId.isEmpty {
            return directoryURL.appendingPathComponent("retriever.sqlite")
        }
        return directoryURL.appendingPathComponent("index-\(projectId).sqlite")
    }

    func getRetriever(for projectId: String, settings: Settings) throws -> LocalRetriever {
        lock.lock()
        defer { lock.unlock() }

        if let cached = cache[projectId],
           cached.settings.qaThreshold == settings.qaThreshold,
           cached.settings.chunkThreshold == settings.chunkThreshold,
           cached.settings.topK == settings.topK {
            return cached.retriever
        }

        let dbURL = databaseURL(for: projectId)
        let retriever = try LocalRetriever(
            databaseURL: dbURL,
            qaThreshold: settings.qaThreshold,
            chunkThreshold: settings.chunkThreshold,
            topK: settings.topK
        )
        cache[projectId] = (retriever, settings)
        return retriever
    }

    private func getActiveRetriever() throws -> LocalRetriever {
        let settings = settingsStore.load()
        let activeProject = settings.activeProjectId.isEmpty ? Project.defaultId : settings.activeProjectId
        return try getRetriever(for: activeProject, settings: settings)
    }

    func deleteIndex(for projectId: String) throws {
        lock.lock()
        defer { lock.unlock() }

        guard projectId != Project.defaultId else { return }
        cache.removeValue(forKey: projectId)

        let dbURL = databaseURL(for: projectId)
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: dbURL.path) {
            try fileManager.removeItem(at: dbURL)
        }
        let walURL = URL(fileURLWithPath: dbURL.path + "-wal")
        if fileManager.fileExists(atPath: walURL.path) {
            try? fileManager.removeItem(at: walURL)
        }
        let shmURL = URL(fileURLWithPath: dbURL.path + "-shm")
        if fileManager.fileExists(atPath: shmURL.path) {
            try? fileManager.removeItem(at: shmURL)
        }
    }

    func stats(for projectId: String) -> (filesCount: Int, chunksCount: Int) {
        let settings = settingsStore.load()
        do {
            let retriever = try getRetriever(for: projectId, settings: settings)
            return retriever.stats()
        } catch {
            return (0, 0)
        }
    }

    func listSources(for projectId: String) -> [MaterialSource] {
        let settings = settingsStore.load()
        do {
            let retriever = try getRetriever(for: projectId, settings: settings)
            return retriever.listSources()
        } catch {
            return []
        }
    }

    func listActiveSources() -> [MaterialSource] {
        let settings = settingsStore.load()
        let activeProject = settings.activeProjectId.isEmpty ? Project.defaultId : settings.activeProjectId
        return listSources(for: activeProject)
    }

    // MARK: - MaterialIndexable

    func index(_ items: [IndexedChunk]) throws {
        let retriever = try getActiveRetriever()
        try retriever.index(items)
    }

    func removeSource(_ path: String) throws {
        let retriever = try getActiveRetriever()
        try retriever.removeSource(path)
    }

    // MARK: - Retriever

    func retrieve(_ question: String) async throws -> Retrieval {
        let retriever = try getActiveRetriever()
        return try await retriever.retrieve(question)
    }
}
