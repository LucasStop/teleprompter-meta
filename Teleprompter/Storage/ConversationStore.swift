import Foundation
import SQLite3

// MARK: - Modelos de Domínio

enum MessageRole: String, Sendable, Codable, Equatable {
    case question, answer
    static let pergunta = MessageRole.question
    static let resposta = MessageRole.answer
}

struct Message: Identifiable, Sendable, Equatable {
    let id: UUID
    var role: MessageRole
    var text: String
    var sources: [SourceRef]
    var latencyMs: Int?
    var createdAt: Date

    init(
        id: UUID = UUID(), role: MessageRole, text: String, sources: [SourceRef] = [],
        latencyMs: Int? = nil, createdAt: Date = Date()
    ) {
        self.id = id; self.role = role; self.text = text
        self.sources = sources; self.latencyMs = latencyMs; self.createdAt = createdAt
    }
}

struct Conversation: Identifiable, Sendable, Equatable {
    let id: UUID
    var title: String
    var projectId: String
    var createdAt: Date
    var updatedAt: Date
    var messages: [Message]
    var messageCount: Int { messages.count }

    init(
        id: UUID = UUID(),
        title: String? = nil,
        projectId: String = "default",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        messages: [Message] = []
    ) {
        self.id = id
        self.projectId = projectId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messages = messages
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedTitle, !trimmedTitle.isEmpty {
            self.title = trimmedTitle
        } else {
            self.title = Self.deriveTitle(from: messages)
        }
    }

    static func deriveTitle(from messages: [Message]) -> String {
        if let firstQuestion = messages.first(where: { $0.role == .question }) {
            return deriveTitle(from: firstQuestion.text)
        }
        return "Nova conversa"
    }

    static func deriveTitle(from question: String, maxLength: Int = 60) -> String {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Nova conversa" }
        let firstLine = trimmed.components(separatedBy: .newlines).first ?? trimmed
        let clean = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return "Nova conversa" }
        if clean.count <= maxLength { return clean }
        return "\(clean.prefix(maxLength))..."
    }
}

// MARK: - Protocolo e Erros

protocol ConversationStore: Sendable {
    func save(_ conversation: Conversation) async throws
    func list() async throws -> [Conversation]
    func load(id: UUID) async throws -> Conversation?
    func delete(id: UUID) async throws
    func deleteAll() async throws
    func deleteAll(forProjectId projectId: String) async throws
    func list(forProjectId projectId: String) async throws -> [Conversation]
    func count(forProjectId projectId: String) async throws -> Int
}

enum ConversationStoreError: Error, LocalizedError, Sendable {
    case databaseOpenFailed(Int32)
    case databaseExecutionFailed(String)

    var errorDescription: String? {
        switch self {
        case .databaseOpenFailed(let code):
            return "Falha ao abrir banco de dados de conversas (código: \(code))."
        case .databaseExecutionFailed(let message):
            return "Erro ao executar operação no SQLite: \(message)."
        }
    }
}

// MARK: - SQLite Conversation Store

final class SQLiteConversationStore: ConversationStore, @unchecked Sendable {
    static let currentSchemaVersion: Int32 = 2

    let database: OpaquePointer
    let queue = DispatchQueue(label: "br.com.lucasstop.teleprompter.storage.conversation")
    private var activeProjectIdProvider: (@Sendable () -> String)?

    init(databaseURL: URL, activeProjectIdProvider: (@Sendable () -> String)? = nil) throws {
        self.activeProjectIdProvider = activeProjectIdProvider
        let directoryURL = databaseURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directoryURL.path) {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }
        var dbPointer: OpaquePointer?
        let openResult = sqlite3_open(databaseURL.path, &dbPointer)
        guard openResult == SQLITE_OK, let dbPointer else {
            throw ConversationStoreError.databaseOpenFailed(openResult)
        }
        self.database = dbPointer
        try configurePragmas()
        try migrate(to: Self.currentSchemaVersion)
    }

    func setActiveProjectIdProvider(_ provider: @escaping @Sendable () -> String) {
        self.activeProjectIdProvider = provider
    }

    private func currentActiveProjectId() -> String {
        activeProjectIdProvider?() ?? Project.defaultId
    }

    private func configurePragmas() throws {
        try executeSQL("PRAGMA journal_mode = WAL; PRAGMA synchronous = NORMAL; PRAGMA foreign_keys = ON;")
    }

    deinit { sqlite3_close(database) }

    func userVersion() throws -> Int32 {
        var version: Int32 = 0
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(database, "PRAGMA user_version;", -1, &stmt, nil) == SQLITE_OK else {
            throw ConversationStoreError.databaseExecutionFailed(String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(stmt) }
        if sqlite3_step(stmt) == SQLITE_ROW { version = sqlite3_column_int(stmt, 0) }
        return version
    }

    func migrate(to targetVersion: Int32 = currentSchemaVersion) throws {
        let current = try userVersion()
        if current < 1 && targetVersion >= 1 {
            let sql = """
            PRAGMA journal_mode = WAL; PRAGMA synchronous = NORMAL; PRAGMA foreign_keys = ON;
            CREATE TABLE IF NOT EXISTS conversations (
                id TEXT PRIMARY KEY, title TEXT NOT NULL, created_at REAL NOT NULL, updated_at REAL NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_conversations_updated_at ON conversations(updated_at DESC);
            CREATE TABLE IF NOT EXISTS messages (
                id TEXT PRIMARY KEY, conversation_id TEXT NOT NULL, role TEXT NOT NULL, text TEXT NOT NULL,
                sources TEXT NOT NULL, latency_ms INTEGER, created_at REAL NOT NULL,
                FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
            );
            CREATE INDEX IF NOT EXISTS idx_messages_conversation ON messages(conversation_id, created_at ASC);
            PRAGMA user_version = 1;
            """
            try executeSQL(sql)
        }

        if current < 2 && targetVersion >= 2 {
            let sql = """
            ALTER TABLE conversations ADD COLUMN project_id TEXT NOT NULL DEFAULT 'default';
            CREATE INDEX IF NOT EXISTS idx_conversations_project ON conversations(project_id, updated_at DESC);
            PRAGMA user_version = 2;
            """
            try executeSQL(sql)
        }
    }

    func rollback(to targetVersion: Int32 = 0) throws {
        let current = try userVersion()
        if current >= 2 && targetVersion <= 1 {
            let sql = """
            DROP INDEX IF EXISTS idx_conversations_project;
            ALTER TABLE conversations DROP COLUMN project_id;
            PRAGMA user_version = 1;
            """
            try executeSQL(sql)
        }

        if current >= 1 && targetVersion == 0 {
            let sql = """
            DROP INDEX IF EXISTS idx_conversations_project;
            DROP INDEX IF EXISTS idx_messages_conversation;
            DROP TABLE IF EXISTS messages;
            DROP INDEX IF EXISTS idx_conversations_updated_at;
            DROP TABLE IF EXISTS conversations;
            PRAGMA user_version = 0;
            """
            try executeSQL(sql)
        }
    }

    func executeSQL(_ sql: String) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(database, sql, nil, nil, &errorMessage) != SQLITE_OK {
            let message = errorMessage.map { String(cString: $0) } ?? "Erro desconhecido"
            sqlite3_free(errorMessage)
            throw ConversationStoreError.databaseExecutionFailed(message)
        }
    }

    func execute(_ sql: String, bind: ((OpaquePointer) -> Void)? = nil) throws {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw ConversationStoreError.databaseExecutionFailed(String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(stmt) }
        bind?(stmt)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw ConversationStoreError.databaseExecutionFailed(String(cString: sqlite3_errmsg(database)))
        }
    }

    func query<T>(
        _ sql: String,
        bind: ((OpaquePointer) -> Void)? = nil,
        parse: (OpaquePointer) -> T?
    ) throws -> [T] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw ConversationStoreError.databaseExecutionFailed(String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(stmt) }
        bind?(stmt)
        var results: [T] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let item = parse(stmt) { results.append(item) }
        }
        return results
    }

    func save(_ conversation: Conversation) async throws {
        let activeProj = currentActiveProjectId()
        try await runOnQueue { try self.performSave(conversation, defaultProjectId: activeProj) }
    }

    func list() async throws -> [Conversation] {
        let activeProj = currentActiveProjectId()
        return try await list(forProjectId: activeProj)
    }

    func list(forProjectId projectId: String) async throws -> [Conversation] {
        try await runOnQueue { try self.performList(forProjectId: projectId) }
    }

    func count(forProjectId projectId: String) async throws -> Int {
        try await runOnQueue { try self.performCount(forProjectId: projectId) }
    }

    func load(id: UUID) async throws -> Conversation? {
        try await runOnQueue { try self.performLoad(id: id) }
    }

    func delete(id: UUID) async throws {
        try await runOnQueue { try self.performDelete(id: id) }
    }

    func deleteAll() async throws {
        let activeProj = currentActiveProjectId()
        try await deleteAll(forProjectId: activeProj)
    }

    func deleteAll(forProjectId projectId: String) async throws {
        try await runOnQueue { try self.performDeleteAll(forProjectId: projectId) }
    }

    private func runOnQueue<T: Sendable>(_ block: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    continuation.resume(returning: try block())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
