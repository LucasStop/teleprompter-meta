import Foundation
import SQLite3
import XCTest
@testable import Teleprompter

// swiftlint:disable:next type_body_length
final class ConversationStoreTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversationStoreTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        try super.tearDownWithError()
    }

    private func makeStore() throws -> SQLiteConversationStore {
        let dbURL = tempDirectory.appendingPathComponent("conversations.sqlite")
        return try SQLiteConversationStore(databaseURL: dbURL)
    }

    func testEmptyStoreReturnsEmptyListAndNilOnLoad() async throws {
        let store = try makeStore()

        let list = try await store.list()
        XCTAssertTrue(list.isEmpty)

        let loaded = try await store.load(id: UUID())
        XCTAssertNil(loaded)
    }

    func testRoundTripSaveAndLoad() async throws {
        let store = try makeStore()

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let convId = UUID()
        let qId = UUID()
        let aId = UUID()

        let question = Message(
            id: qId,
            role: .question,
            text: "Por que Swift nativo e não Flutter?",
            sources: [],
            latencyMs: nil,
            createdAt: now
        )
        let answer = Message(
            id: aId,
            role: .answer,
            text: "DAT SDK só tem módulos Swift nativos.",
            sources: [SourceRef(path: "qa/stack.md"), SourceRef(path: "docs/ADR-0001.md")],
            latencyMs: 820,
            createdAt: now.addingTimeInterval(1)
        )

        let conversation = Conversation(
            id: convId,
            title: "Por que Swift nativo e não Flutter?",
            createdAt: now,
            updatedAt: now.addingTimeInterval(1),
            messages: [question, answer]
        )

        try await store.save(conversation)

        guard let loaded = try await store.load(id: convId) else {
            XCTFail("Conversa não encontrada após save")
            return
        }

        XCTAssertEqual(loaded.id, convId)
        XCTAssertEqual(loaded.title, "Por que Swift nativo e não Flutter?")
        XCTAssertEqual(loaded.createdAt.timeIntervalSince1970, now.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(loaded.updatedAt.timeIntervalSince1970, now.addingTimeInterval(1).timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(loaded.messages.count, 2)

        let loadedQ = loaded.messages[0]
        XCTAssertEqual(loadedQ.id, qId)
        XCTAssertEqual(loadedQ.role, .question)
        XCTAssertEqual(loadedQ.text, "Por que Swift nativo e não Flutter?")
        XCTAssertTrue(loadedQ.sources.isEmpty)
        XCTAssertNil(loadedQ.latencyMs)

        let loadedA = loaded.messages[1]
        XCTAssertEqual(loadedA.id, aId)
        XCTAssertEqual(loadedA.role, .answer)
        XCTAssertEqual(loadedA.text, "DAT SDK só tem módulos Swift nativos.")
        XCTAssertEqual(loadedA.sources, [SourceRef(path: "qa/stack.md"), SourceRef(path: "docs/ADR-0001.md")])
        XCTAssertEqual(loadedA.latencyMs, 820)
    }

    func testListOrdersByUpdatedAtDescending() async throws {
        let store = try makeStore()
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

        let conv1 = Conversation(
            id: UUID(),
            title: "Primeira (mais antiga)",
            createdAt: baseDate,
            updatedAt: baseDate.addingTimeInterval(-100),
            messages: []
        )
        let conv2 = Conversation(
            id: UUID(),
            title: "Segunda (mais recente)",
            createdAt: baseDate,
            updatedAt: baseDate.addingTimeInterval(200),
            messages: []
        )
        let conv3 = Conversation(
            id: UUID(),
            title: "Terceira (intermediária)",
            createdAt: baseDate,
            updatedAt: baseDate,
            messages: []
        )

        try await store.save(conv1)
        try await store.save(conv2)
        try await store.save(conv3)

        let list = try await store.list()
        XCTAssertEqual(list.count, 3)
        XCTAssertEqual(list[0].id, conv2.id)
        XCTAssertEqual(list[1].id, conv3.id)
        XCTAssertEqual(list[2].id, conv1.id)
    }

    func testDeleteSingleConversationAndItsMessages() async throws {
        let store = try makeStore()
        let now = Date()

        let msg1 = Message(role: .question, text: "Pergunta 1")
        let conv1 = Conversation(title: "C1", createdAt: now, updatedAt: now, messages: [msg1])

        let msg2 = Message(role: .question, text: "Pergunta 2")
        let conv2 = Conversation(title: "C2", createdAt: now, updatedAt: now.addingTimeInterval(10), messages: [msg2])

        try await store.save(conv1)
        try await store.save(conv2)

        var list = try await store.list()
        XCTAssertEqual(list.count, 2)

        try await store.delete(id: conv1.id)

        list = try await store.list()
        XCTAssertEqual(list.count, 1)
        XCTAssertEqual(list.first?.id, conv2.id)

        let deleted = try await store.load(id: conv1.id)
        XCTAssertNil(deleted)
    }

    func testDeleteAllConversations() async throws {
        let store = try makeStore()
        let now = Date()

        for idx in 1...3 {
            let conv = Conversation(
                title: "Conversa \(idx)",
                createdAt: now,
                updatedAt: now.addingTimeInterval(Double(idx)),
                messages: [Message(role: .question, text: "Pergunta \(idx)")]
            )
            try await store.save(conv)
        }

        var list = try await store.list()
        XCTAssertEqual(list.count, 3)

        try await store.deleteAll()

        list = try await store.list()
        XCTAssertTrue(list.isEmpty)
    }

    private func countRowsInTable(_ tableName: String, databaseURL: URL) throws -> Int {
        var dbPointer: OpaquePointer?
        guard sqlite3_open(databaseURL.path, &dbPointer) == SQLITE_OK, let dbPointer else {
            return -1
        }
        defer { sqlite3_close(dbPointer) }
        var stmt: OpaquePointer?
        let sql = "SELECT COUNT(*) FROM \(tableName);"
        guard sqlite3_prepare_v2(dbPointer, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            return -1
        }
        defer { sqlite3_finalize(stmt) }
        if sqlite3_step(stmt) == SQLITE_ROW {
            return Int(sqlite3_column_int(stmt, 0))
        }
        return 0
    }

    func testReopenedDatabaseEnforcesForeignKeyCascadeOnDeleteAndCountIsZero() async throws {
        let dbURL = tempDirectory.appendingPathComponent("reopen_cascade.sqlite")

        // 1. Abre a conexão inicial (user_version vai de 0 para 1) e salva conversas com mensagens
        var store: SQLiteConversationStore? = try SQLiteConversationStore(databaseURL: dbURL)
        let conversation1 = Conversation(
            title: "Conversa 1",
            messages: [
                Message(role: .question, text: "Pergunta 1"),
                Message(role: .answer, text: "Resposta 1")
            ]
        )
        let conversation2 = Conversation(
            title: "Conversa 2",
            messages: [
                Message(role: .question, text: "Pergunta 2"),
                Message(role: .answer, text: "Resposta 2")
            ]
        )
        try await store?.save(conversation1)
        try await store?.save(conversation2)

        var rawMessageCount = try countRowsInTable("messages", databaseURL: dbURL)
        XCTAssertEqual(rawMessageCount, 4)

        // 2. Fecha o store inicial (simula reinicialização do app)
        store = nil

        // 3. Reabre o store com user_version já igual a 1
        let reopenedStore = try SQLiteConversationStore(databaseURL: dbURL)

        // 4. Apaga conversation1 e valida que o cascade deletou as mensagens órfãs no SQLite
        try await reopenedStore.delete(id: conversation1.id)
        rawMessageCount = try countRowsInTable("messages", databaseURL: dbURL)
        XCTAssertEqual(rawMessageCount, 2)

        // 5. Apaga todas as conversas e valida que a contagem de mensagens no SQLite é 0
        try await reopenedStore.deleteAll()
        rawMessageCount = try countRowsInTable("messages", databaseURL: dbURL)
        XCTAssertEqual(rawMessageCount, 0)
    }

    func testSchemaVersionAndReversibleMigration() async throws {
        let store = try makeStore()

        let initialVersion = try store.userVersion()
        XCTAssertEqual(initialVersion, SQLiteConversationStore.currentSchemaVersion)
        XCTAssertEqual(initialVersion, 1)

        // Salva dado para validar integridade pré-rollback
        let conv = Conversation(
            title: "Teste Migração",
            messages: [Message(role: .question, text: "Como reverter?")]
        )
        try await store.save(conv)

        // Reversão documentada para a versão 0 (drop tables e reset user_version)
        try store.rollback(to: 0)
        let versionAfterRollback = try store.userVersion()
        XCTAssertEqual(versionAfterRollback, 0)

        // Nova migração para versão 1
        try store.migrate(to: 1)
        let versionAfterMigration = try store.userVersion()
        XCTAssertEqual(versionAfterMigration, 1)

        // Banco volta a estar operacional
        let emptyList = try await store.list()
        XCTAssertTrue(emptyList.isEmpty)

        try await store.save(conv)
        let reloaded = try await store.load(id: conv.id)
        XCTAssertNotNil(reloaded)
        XCTAssertEqual(reloaded?.title, "Teste Migração")
    }

    func testDerivedTitleLogic() {
        // Pergunta curta direta
        let title1 = Conversation.deriveTitle(from: "Por que Swift nativo e não Flutter?")
        XCTAssertEqual(title1, "Por que Swift nativo e não Flutter?")

        // Pergunta longa truncada com ...
        let longQuestion = "Qual é exatamente o objetivo da arquitetura monolítica no Teleprompter Meta " +
            "quando estamos rodando localmente sem servidor?"
        let title2 = Conversation.deriveTitle(from: longQuestion, maxLength: 40)
        XCTAssertEqual(title2, "Qual é exatamente o objetivo da arquitet...")
        XCTAssertTrue(title2.hasSuffix("..."))

        // Pergunta multilinha (usa primeira linha)
        let multiline = "Primeira linha importante\nSegunda linha complementar"
        let title3 = Conversation.deriveTitle(from: multiline)
        XCTAssertEqual(title3, "Primeira linha importante")

        // Pergunta vazia
        let empty = Conversation.deriveTitle(from: "   \n\t  ")
        XCTAssertEqual(empty, "Nova conversa")

        // Derivação automática no construtor de Conversation a partir da primeira pergunta
        let convAuto = Conversation(
            messages: [
                Message(role: .answer, text: "Resposta inicial estranha"),
                Message(role: .question, text: "Ensaio da banca")
            ]
        )
        XCTAssertEqual(convAuto.title, "Ensaio da banca")
    }

    func testInMemoryConversationStoreRoundTrip() async throws {
        let store = InMemoryConversationStore()

        let listInitial = try await store.list()
        XCTAssertTrue(listInitial.isEmpty)

        let conv = Conversation(
            title: "Em memória",
            messages: [Message(role: .question, text: "Funciona?")]
        )
        try await store.save(conv)

        let listAfter = try await store.list()
        XCTAssertEqual(listAfter.count, 1)
        XCTAssertEqual(listAfter.first?.title, "Em memória")

        let loaded = try await store.load(id: conv.id)
        XCTAssertEqual(loaded?.id, conv.id)

        try await store.delete(id: conv.id)
        let listFinal = try await store.list()
        XCTAssertTrue(listFinal.isEmpty)
    }
}
