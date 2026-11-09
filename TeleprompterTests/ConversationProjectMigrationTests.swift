import Foundation
import SQLite3
import XCTest
@testable import Teleprompter

final class ConversationProjectMigrationTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MigrationTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        try super.tearDownWithError()
    }

    private func createV1Database(at url: URL) throws {
        var databasePointer: OpaquePointer?
        guard sqlite3_open(url.path, &databasePointer) == SQLITE_OK, let databasePointer else {
            throw ConversationStoreError.databaseOpenFailed(-1)
        }
        defer { sqlite3_close(databasePointer) }

        let schemaV1 = """
        PRAGMA foreign_keys = ON;
        CREATE TABLE conversations (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL
        );
        CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
            role TEXT NOT NULL,
            text TEXT NOT NULL,
            sources_json TEXT NOT NULL DEFAULT '[]',
            latency_ms INTEGER,
            created_at REAL NOT NULL
        );
        PRAGMA user_version = 1;
        """
        guard sqlite3_exec(databasePointer, schemaV1, nil, nil, nil) == SQLITE_OK else {
            throw ConversationStoreError.databaseExecutionFailed("Falha ao criar v1")
        }

        let insert = """
        INSERT INTO conversations (id, title, created_at, updated_at)
        VALUES ('c-1', 'Conversa Legada', 1700000000.0, 1700000000.0);
        INSERT INTO messages (id, conversation_id, role, text, created_at)
        VALUES ('m-1', 'c-1', 'question', 'Pergunta legada', 1700000000.0);
        """
        guard sqlite3_exec(databasePointer, insert, nil, nil, nil) == SQLITE_OK else {
            throw ConversationStoreError.databaseExecutionFailed("Falha ao inserir legada")
        }
    }

    func testV1ToV2MigrationAssignsDefaultProject() async throws {
        let dbURL = tempDirectory.appendingPathComponent("mig_test.sqlite")
        try createV1Database(at: dbURL)

        // Abrir via SQLiteConversationStore deve executar migração v1 -> v2 automaticamente
        let store = try SQLiteConversationStore(databaseURL: dbURL)
        let version = try store.userVersion()
        XCTAssertEqual(version, 2)

        let loaded = try await store.load(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID())
        // Verificar diretamente no banco que a conversa c-1 tem project_id = 'default'
        var databasePointer: OpaquePointer?
        guard sqlite3_open(dbURL.path, &databasePointer) == SQLITE_OK, let databasePointer else {
            XCTFail("Falha ao abrir db")
            return
        }
        defer { sqlite3_close(databasePointer) }

        var stmt: OpaquePointer?
        let sql = "SELECT project_id, title FROM conversations WHERE id = 'c-1';"
        guard sqlite3_prepare_v2(databasePointer, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            XCTFail("Falha no prepare")
            return
        }
        defer { sqlite3_finalize(stmt) }

        XCTAssertEqual(sqlite3_step(stmt), SQLITE_ROW)
        let projId = String(cString: sqlite3_column_text(stmt, 0))
        let title = String(cString: sqlite3_column_text(stmt, 1))
        XCTAssertEqual(projId, "default")
        XCTAssertEqual(title, "Conversa Legada")
        _ = loaded
    }

    func testV2DownToV1PreservesConversations() async throws {
        let dbURL = tempDirectory.appendingPathComponent("mig_down.sqlite")
        let store = try SQLiteConversationStore(databaseURL: dbURL)

        let conv = Conversation(title: "Conversa V2", messages: [])
        try await store.save(conv)

        XCTAssertEqual(try store.userVersion(), 2)

        // Down migration para v1
        try store.rollback(to: 1)
        XCTAssertEqual(try store.userVersion(), 1)

        // Conversa continua existindo
        let list = try await store.list()
        XCTAssertEqual(list.count, 1)
        XCTAssertEqual(list.first?.title, "Conversa V2")

        // Migrar de novo para v2
        try store.migrate(to: 2)
        XCTAssertEqual(try store.userVersion(), 2)
        let listV2 = try await store.list()
        XCTAssertEqual(listV2.count, 1)
    }
}
