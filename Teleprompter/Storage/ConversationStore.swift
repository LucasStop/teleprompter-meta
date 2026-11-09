import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

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
    var createdAt: Date
    var updatedAt: Date
    var messages: [Message]
    var messageCount: Int { messages.count }

    init(
        id: UUID = UUID(), title: String? = nil, createdAt: Date = Date(),
        updatedAt: Date = Date(), messages: [Message] = []
    ) {
        self.id = id; self.createdAt = createdAt; self.updatedAt = updatedAt; self.messages = messages
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

private struct ConversationRecord: Sendable {
    let id: UUID
    let title: String
    let createdAt: Date
    let updatedAt: Date
}

// MARK: - SQLite Conversation Store

final class SQLiteConversationStore: ConversationStore, @unchecked Sendable {
    static let currentSchemaVersion: Int32 = 1

    fileprivate let database: OpaquePointer
    fileprivate let queue = DispatchQueue(label: "br.com.lucasstop.teleprompter.storage.conversation")

    init(databaseURL: URL) throws {
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
    }

    func rollback(to targetVersion: Int32 = 0) throws {
        let current = try userVersion()
        if current >= 1 && targetVersion == 0 {
            let sql = """
            DROP INDEX IF EXISTS idx_messages_conversation; DROP TABLE IF EXISTS messages;
            DROP INDEX IF EXISTS idx_conversations_updated_at; DROP TABLE IF EXISTS conversations;
            PRAGMA user_version = 0;
            """
            try executeSQL(sql)
        }
    }

    fileprivate func executeSQL(_ sql: String) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(database, sql, nil, nil, &errorMessage) != SQLITE_OK {
            let message = errorMessage.map { String(cString: $0) } ?? "Erro desconhecido"
            sqlite3_free(errorMessage)
            throw ConversationStoreError.databaseExecutionFailed(message)
        }
    }

    fileprivate func execute(_ sql: String, bind: ((OpaquePointer) -> Void)? = nil) throws {
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

    fileprivate func query<T>(_ sql: String, bind: ((OpaquePointer) -> Void)? = nil, parse: (OpaquePointer) -> T?) throws -> [T] {
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
        try await runOnQueue { try self.performSave(conversation) }
    }
    func list() async throws -> [Conversation] {
        try await runOnQueue { try self.performList() }
    }
    func load(id: UUID) async throws -> Conversation? {
        try await runOnQueue { try self.performLoad(id: id) }
    }
    func delete(id: UUID) async throws {
        try await runOnQueue { try self.performDelete(id: id) }
    }
    func deleteAll() async throws {
        try await runOnQueue { try self.performDeleteAll() }
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

// MARK: - Operações Internas SQLite

extension SQLiteConversationStore {
    fileprivate func performSave(_ conv: Conversation) throws {
        try executeSQL("BEGIN IMMEDIATE TRANSACTION;")
        do {
            let upsertSQL = """
            INSERT INTO conversations (id, title, created_at, updated_at) VALUES (?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET title = excluded.title, created_at = excluded.created_at, updated_at = excluded.updated_at;
            """
            try execute(upsertSQL) { stmt in
                sqlite3_bind_text(stmt, 1, conv.id.uuidString, -1, sqliteTransient)
                sqlite3_bind_text(stmt, 2, conv.title, -1, sqliteTransient)
                sqlite3_bind_double(stmt, 3, conv.createdAt.timeIntervalSince1970)
                sqlite3_bind_double(stmt, 4, conv.updatedAt.timeIntervalSince1970)
            }
            try execute("DELETE FROM messages WHERE conversation_id = ?;") { stmt in
                sqlite3_bind_text(stmt, 1, conv.id.uuidString, -1, sqliteTransient)
            }
            let insertMsgSQL = """
            INSERT INTO messages (id, conversation_id, role, text, sources, latency_ms, created_at) VALUES (?, ?, ?, ?, ?, ?, ?);
            """
            for msg in conv.messages {
                let sourcesJSON = serializeSources(msg.sources)
                try execute(insertMsgSQL) { stmt in
                    sqlite3_bind_text(stmt, 1, msg.id.uuidString, -1, sqliteTransient)
                    sqlite3_bind_text(stmt, 2, conv.id.uuidString, -1, sqliteTransient)
                    sqlite3_bind_text(stmt, 3, msg.role.rawValue, -1, sqliteTransient)
                    sqlite3_bind_text(stmt, 4, msg.text, -1, sqliteTransient)
                    sqlite3_bind_text(stmt, 5, sourcesJSON, -1, sqliteTransient)
                    if let lat = msg.latencyMs { sqlite3_bind_int64(stmt, 6, Int64(lat)) } else { sqlite3_bind_null(stmt, 6) }
                    sqlite3_bind_double(stmt, 7, msg.createdAt.timeIntervalSince1970)
                }
            }
            try executeSQL("COMMIT;")
        } catch {
            try? executeSQL("ROLLBACK;")
            throw error
        }
    }

    fileprivate func performList() throws -> [Conversation] {
        let sql = "SELECT id, title, created_at, updated_at FROM conversations ORDER BY updated_at DESC;"
        let records = try query(sql) { stmt -> ConversationRecord? in
            guard let idStr = sqlite3_column_text(stmt, 0).map({ String(cString: $0) }),
                  let id = UUID(uuidString: idStr),
                  let title = sqlite3_column_text(stmt, 1).map({ String(cString: $0) }) else { return nil }
            return ConversationRecord(
                id: id, title: title,
                createdAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 2)),
                updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 3))
            )
        }
        return try records.map { rec in
            let msgs = try loadMessages(forConversationId: rec.id)
            return Conversation(id: rec.id, title: rec.title, createdAt: rec.createdAt, updatedAt: rec.updatedAt, messages: msgs)
        }
    }

    fileprivate func performLoad(id: UUID) throws -> Conversation? {
        let sql = "SELECT id, title, created_at, updated_at FROM conversations WHERE id = ?;"
        let records = try query(sql, bind: { stmt in
            sqlite3_bind_text(stmt, 1, id.uuidString, -1, sqliteTransient)
        }, parse: { stmt -> ConversationRecord? in
            guard let idStr = sqlite3_column_text(stmt, 0).map({ String(cString: $0) }),
                  let parsedId = UUID(uuidString: idStr),
                  let title = sqlite3_column_text(stmt, 1).map({ String(cString: $0) }) else { return nil }
            return ConversationRecord(
                id: parsedId, title: title,
                createdAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 2)),
                updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 3))
            )
        })
        guard let first = records.first else { return nil }
        let msgs = try loadMessages(forConversationId: first.id)
        return Conversation(id: first.id, title: first.title, createdAt: first.createdAt, updatedAt: first.updatedAt, messages: msgs)
    }

    private func loadMessages(forConversationId convId: UUID) throws -> [Message] {
        let sql = "SELECT id, role, text, sources, latency_ms, created_at FROM messages WHERE conversation_id = ? ORDER BY created_at ASC;"
        return try query(sql, bind: { stmt in
            sqlite3_bind_text(stmt, 1, convId.uuidString, -1, sqliteTransient)
        }, parse: { stmt -> Message? in
            guard let idStr = sqlite3_column_text(stmt, 0).map({ String(cString: $0) }),
                  let id = UUID(uuidString: idStr),
                  let roleStr = sqlite3_column_text(stmt, 1).map({ String(cString: $0) }),
                  let role = MessageRole(rawValue: roleStr),
                  let text = sqlite3_column_text(stmt, 2).map({ String(cString: $0) }),
                  let sourcesJSON = sqlite3_column_text(stmt, 3).map({ String(cString: $0) }) else { return nil }
            let latencyMs = sqlite3_column_type(stmt, 4) == SQLITE_NULL ? nil : Int(sqlite3_column_int64(stmt, 4))
            let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 5))
            let sources = deserializeSources(sourcesJSON)
            return Message(id: id, role: role, text: text, sources: sources, latencyMs: latencyMs, createdAt: createdAt)
        })
    }

    fileprivate func performDelete(id: UUID) throws {
        try execute("DELETE FROM conversations WHERE id = ?;") { stmt in
            sqlite3_bind_text(stmt, 1, id.uuidString, -1, sqliteTransient)
        }
    }

    fileprivate func performDeleteAll() throws {
        try executeSQL("DELETE FROM messages; DELETE FROM conversations;")
    }

    private func serializeSources(_ sources: [SourceRef]) -> String {
        guard let data = try? JSONEncoder().encode(sources.map(\.path)),
              let str = String(data: data, encoding: .utf8) else { return "[]" }
        return str
    }

    private func deserializeSources(_ json: String) -> [SourceRef] {
        guard let data = json.data(using: .utf8),
              let paths = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return paths.map { SourceRef(path: $0) }
    }
}

// MARK: - InMemoryConversationStore

actor InMemoryConversationStore: ConversationStore {
    private var conversations: [UUID: Conversation] = [:]

    init(initialConversations: [Conversation] = []) {
        for conv in initialConversations { conversations[conv.id] = conv }
    }
    func save(_ conversation: Conversation) async throws {
        conversations[conversation.id] = conversation
    }
    func list() async throws -> [Conversation] {
        return conversations.values.sorted { $0.updatedAt > $1.updatedAt }
    }
    func load(id: UUID) async throws -> Conversation? {
        return conversations[id]
    }
    func delete(id: UUID) async throws {
        conversations.removeValue(forKey: id)
    }
    func deleteAll() async throws {
        conversations.removeAll()
    }
}
