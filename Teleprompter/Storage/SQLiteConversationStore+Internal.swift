import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

struct ConversationRecord: Sendable {
    let id: UUID
    let title: String
    let projectId: String
    let createdAt: Date
    let updatedAt: Date
}

// MARK: - Operações Internas SQLite

extension SQLiteConversationStore {
    func performSave(_ conv: Conversation, defaultProjectId: String) throws {
        let targetProjectId = (conv.projectId.isEmpty || conv.projectId == Project.defaultId)
            ? (defaultProjectId.isEmpty ? Project.defaultId : defaultProjectId)
            : conv.projectId

        try executeSQL("BEGIN IMMEDIATE TRANSACTION;")
        do {
            let upsertSQL = """
            INSERT INTO conversations (id, title, project_id, created_at, updated_at) VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET title = excluded.title, project_id = excluded.project_id,
            created_at = excluded.created_at, updated_at = excluded.updated_at;
            """
            try execute(upsertSQL) { stmt in
                sqlite3_bind_text(stmt, 1, conv.id.uuidString, -1, sqliteTransient)
                sqlite3_bind_text(stmt, 2, conv.title, -1, sqliteTransient)
                sqlite3_bind_text(stmt, 3, targetProjectId, -1, sqliteTransient)
                sqlite3_bind_double(stmt, 4, conv.createdAt.timeIntervalSince1970)
                sqlite3_bind_double(stmt, 5, conv.updatedAt.timeIntervalSince1970)
            }
            try execute("DELETE FROM messages WHERE conversation_id = ?;") { stmt in
                sqlite3_bind_text(stmt, 1, conv.id.uuidString, -1, sqliteTransient)
            }
            let insertMsgSQL = """
            INSERT INTO messages (id, conversation_id, role, text, sources, latency_ms, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?);
            """
            for msg in conv.messages {
                let sourcesJSON = serializeSources(msg.sources)
                try execute(insertMsgSQL) { stmt in
                    sqlite3_bind_text(stmt, 1, msg.id.uuidString, -1, sqliteTransient)
                    sqlite3_bind_text(stmt, 2, conv.id.uuidString, -1, sqliteTransient)
                    sqlite3_bind_text(stmt, 3, msg.role.rawValue, -1, sqliteTransient)
                    sqlite3_bind_text(stmt, 4, msg.text, -1, sqliteTransient)
                    sqlite3_bind_text(stmt, 5, sourcesJSON, -1, sqliteTransient)
                    if let lat = msg.latencyMs {
                        sqlite3_bind_int64(stmt, 6, Int64(lat))
                    } else {
                        sqlite3_bind_null(stmt, 6)
                    }
                    sqlite3_bind_double(stmt, 7, msg.createdAt.timeIntervalSince1970)
                }
            }
            try executeSQL("COMMIT;")
        } catch {
            try? executeSQL("ROLLBACK;")
            throw error
        }
    }

    func performList(forProjectId projectId: String) throws -> [Conversation] {
        let version = try userVersion()
        if version >= 2 {
            let sql = "SELECT id, title, project_id, created_at, updated_at FROM conversations "
                + "WHERE project_id = ? ORDER BY updated_at DESC;"
            let records = try query(sql, bind: { stmt in
                sqlite3_bind_text(stmt, 1, projectId, -1, sqliteTransient)
            }, parse: { stmt -> ConversationRecord? in
                parseRecord(stmt)
            })
            return try records.map { rec in
                let msgs = try loadMessages(forConversationId: rec.id)
                return Conversation(
                    id: rec.id, title: rec.title, projectId: rec.projectId,
                    createdAt: rec.createdAt, updatedAt: rec.updatedAt, messages: msgs
                )
            }
        } else {
            guard projectId == Project.defaultId || projectId.isEmpty else { return [] }
            let sql = "SELECT id, title, 'default', created_at, updated_at FROM conversations ORDER BY updated_at DESC;"
            let records = try query(sql, bind: { _ in }, parse: { stmt -> ConversationRecord? in
                parseRecord(stmt)
            })
            return try records.map { rec in
                let msgs = try loadMessages(forConversationId: rec.id)
                return Conversation(
                    id: rec.id, title: rec.title, projectId: rec.projectId,
                    createdAt: rec.createdAt, updatedAt: rec.updatedAt, messages: msgs
                )
            }
        }
    }

    private func parseRecord(_ stmt: OpaquePointer) -> ConversationRecord? {
        guard let idStr = sqlite3_column_text(stmt, 0).map({ String(cString: $0) }),
              let id = UUID(uuidString: idStr),
              let title = sqlite3_column_text(stmt, 1).map({ String(cString: $0) }),
              let project = sqlite3_column_text(stmt, 2).map({ String(cString: $0) }) else { return nil }
        return ConversationRecord(
            id: id, title: title, projectId: project,
            createdAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 3)),
            updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4))
        )
    }

    func performCount(forProjectId projectId: String) throws -> Int {
        let version = try userVersion()
        if version < 2 {
            guard projectId == Project.defaultId || projectId.isEmpty else { return 0 }
            let sql = "SELECT COUNT(*) FROM conversations;"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(database, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
                throw ConversationStoreError.databaseExecutionFailed(String(cString: sqlite3_errmsg(database)))
            }
            defer { sqlite3_finalize(stmt) }
            if sqlite3_step(stmt) == SQLITE_ROW {
                return Int(sqlite3_column_int(stmt, 0))
            }
            return 0
        }

        let sql = "SELECT COUNT(*) FROM conversations WHERE project_id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw ConversationStoreError.databaseExecutionFailed(String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, projectId, -1, sqliteTransient)
        if sqlite3_step(stmt) == SQLITE_ROW {
            return Int(sqlite3_column_int(stmt, 0))
        }
        return 0
    }

    func performLoad(id: UUID) throws -> Conversation? {
        let version = try userVersion()
        let sql: String
        if version >= 2 {
            sql = "SELECT id, title, project_id, created_at, updated_at FROM conversations WHERE id = ?;"
        } else {
            sql = "SELECT id, title, 'default', created_at, updated_at FROM conversations WHERE id = ?;"
        }
        let records = try query(sql, bind: { stmt in
            sqlite3_bind_text(stmt, 1, id.uuidString, -1, sqliteTransient)
        }, parse: { stmt -> ConversationRecord? in
            guard let idStr = sqlite3_column_text(stmt, 0).map({ String(cString: $0) }),
                  let parsedId = UUID(uuidString: idStr),
                  let title = sqlite3_column_text(stmt, 1).map({ String(cString: $0) }),
                  let project = sqlite3_column_text(stmt, 2).map({ String(cString: $0) }) else { return nil }
            return ConversationRecord(
                id: parsedId, title: title, projectId: project,
                createdAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 3)),
                updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4))
            )
        })
        guard let first = records.first else { return nil }
        let msgs = try loadMessages(forConversationId: first.id)
        return Conversation(
            id: first.id, title: first.title, projectId: first.projectId,
            createdAt: first.createdAt, updatedAt: first.updatedAt, messages: msgs
        )
    }

    func loadMessages(forConversationId convId: UUID) throws -> [Message] {
        let sql = "SELECT id, role, text, sources, latency_ms, created_at FROM messages "
            + "WHERE conversation_id = ? ORDER BY created_at ASC;"
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

    func performDelete(id: UUID) throws {
        try execute("DELETE FROM conversations WHERE id = ?;") { stmt in
            sqlite3_bind_text(stmt, 1, id.uuidString, -1, sqliteTransient)
        }
    }

    func performDeleteAll(forProjectId projectId: String) throws {
        try executeSQL("BEGIN IMMEDIATE TRANSACTION;")
        do {
            try execute("DELETE FROM messages WHERE conversation_id IN "
                + "(SELECT id FROM conversations WHERE project_id = ?);") { stmt in
                sqlite3_bind_text(stmt, 1, projectId, -1, sqliteTransient)
            }
            try execute("DELETE FROM conversations WHERE project_id = ?;") { stmt in
                sqlite3_bind_text(stmt, 1, projectId, -1, sqliteTransient)
            }
            try executeSQL("COMMIT;")
        } catch {
            try? executeSQL("ROLLBACK;")
            throw error
        }
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
