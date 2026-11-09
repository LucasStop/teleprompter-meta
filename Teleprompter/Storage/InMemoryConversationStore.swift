import Foundation

// MARK: - InMemoryConversationStore

actor InMemoryConversationStore: ConversationStore {
    private var conversations: [UUID: Conversation] = [:]
    private var activeProjectIdProvider: (@Sendable () -> String)?

    init(
        initialConversations: [Conversation] = [],
        activeProjectIdProvider: (@Sendable () -> String)? = nil
    ) {
        self.activeProjectIdProvider = activeProjectIdProvider
        for conv in initialConversations { conversations[conv.id] = conv }
    }

    func setActiveProjectIdProvider(_ provider: @escaping @Sendable () -> String) {
        self.activeProjectIdProvider = provider
    }

    private func currentActiveProjectId() -> String {
        activeProjectIdProvider?() ?? Project.defaultId
    }

    func save(_ conversation: Conversation) async throws {
        var copy = conversation
        if copy.projectId.isEmpty || copy.projectId == Project.defaultId {
            let active = currentActiveProjectId()
            if !active.isEmpty {
                copy.projectId = active
            }
        }
        conversations[copy.id] = copy
    }

    func list() async throws -> [Conversation] {
        let active = currentActiveProjectId()
        return try await list(forProjectId: active)
    }

    func list(forProjectId projectId: String) async throws -> [Conversation] {
        conversations.values
            .filter { $0.projectId == projectId }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func count(forProjectId projectId: String) async throws -> Int {
        conversations.values.filter { $0.projectId == projectId }.count
    }

    func load(id: UUID) async throws -> Conversation? {
        conversations[id]
    }

    func delete(id: UUID) async throws {
        conversations.removeValue(forKey: id)
    }

    func deleteAll() async throws {
        let active = currentActiveProjectId()
        try await deleteAll(forProjectId: active)
    }

    func deleteAll(forProjectId projectId: String) async throws {
        let toRemove = conversations.values.filter { $0.projectId == projectId }.map(\.id)
        for id in toRemove {
            conversations.removeValue(forKey: id)
        }
    }
}
