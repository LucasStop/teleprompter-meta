import Foundation
import XCTest
@testable import Teleprompter

final class ProjectIsolationIntegrationTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectIsolationTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        try super.tearDownWithError()
    }

    func testLegacySettingsDecodesWithDefaultActiveProjectId() throws {
        // JSON representativo de uma versão antiga do app sem activeProjectId
        let legacyJSON = """
        {
            "format": "bullets",
            "silenceThreshold": 1.2,
            "displaySpeedWpm": 150,
            "hapticFeedback": true,
            "showConfidence": false,
            "qaThreshold": 0.40,
            "chunkThreshold": 0.25,
            "topK": 3,
            "theme": "dark",
            "llmProvider": "apple",
            "openRouterModel": "anthropic/claude-3.5-haiku",
            "customLLMBaseURL": "http://localhost:11434/v1",
            "customLLMModel": "llama3.2"
        }
        """

        let decoder = JSONDecoder()
        let settings = try decoder.decode(Settings.self, from: Data(legacyJSON.utf8))
        XCTAssertEqual(settings.activeProjectId, Project.defaultId)
    }

    func testDefaultProjectUsesRetrieverSqlite() {
        let settingsStore = InMemorySettingsStore()
        let retriever = ProductionAppRetriever(directoryURL: tempDirectory, settingsStore: settingsStore)

        let defaultURL = retriever.databaseURL(for: Project.defaultId)
        XCTAssertEqual(defaultURL.lastPathComponent, "retriever.sqlite")

        let customURL = retriever.databaseURL(for: "proj-123")
        XCTAssertEqual(customURL.lastPathComponent, "index-proj-123.sqlite")
    }

    private func setupAlphaAndBeta(
        retriever: ProductionAppRetriever,
        convStore: SQLiteConversationStore,
        settingsStore: InMemorySettingsStore,
        currentSettings: inout Settings
    ) async throws {
        currentSettings.activeProjectId = "alpha"
        settingsStore.save(currentSettings)
        let chunkA = IndexedChunk(
            kind: .document,
            text: "Conteudo exclusivo do Projeto Alpha sobre arquitetura de dados.",
            source: SourceRef(path: "alpha/dados.md")
        )
        try retriever.index([chunkA])
        try await convStore.save(Conversation(title: "Conversa Alpha", messages: []))

        currentSettings.activeProjectId = "beta"
        settingsStore.save(currentSettings)
        let chunkB = IndexedChunk(
            kind: .document,
            text: "Conteudo exclusivo do Projeto Beta sobre microservicos.",
            source: SourceRef(path: "beta/micro.md")
        )
        try retriever.index([chunkB])
        try await convStore.save(Conversation(title: "Conversa Beta", messages: []))
    }

    func testProjectIsolationBetweenAlphaAndBeta() async throws {
        var currentSettings = Settings.default
        let settingsStore = InMemorySettingsStore(initial: currentSettings)
        let retriever = ProductionAppRetriever(directoryURL: tempDirectory, settingsStore: settingsStore)
        let convStore = try SQLiteConversationStore(
            databaseURL: tempDirectory.appendingPathComponent("conversations.sqlite"),
            activeProjectIdProvider: { settingsStore.load().activeProjectId }
        )

        try await setupAlphaAndBeta(
            retriever: retriever,
            convStore: convStore,
            settingsStore: settingsStore,
            currentSettings: &currentSettings
        )

        // Consulta no Projeto Beta nunca devolve fontes de Alpha
        let retrievalB = try await retriever.retrieve("arquitetura de dados")
        XCTAssertTrue(retrievalB.chunks.isEmpty)

        let retrievalBMatch = try await retriever.retrieve("microservicos")
        XCTAssertEqual(retrievalBMatch.chunks.first?.source.path, "beta/micro.md")

        // Voltar para Alpha: nunca devolve fontes de Beta
        currentSettings.activeProjectId = "alpha"
        settingsStore.save(currentSettings)
        let retrievalA = try await retriever.retrieve("microservicos")
        XCTAssertTrue(retrievalA.chunks.isEmpty)

        // Reimportar em Alpha não altera Beta
        try retriever.index([IndexedChunk(kind: .document, text: "Adendo Alpha", source: SourceRef(path: "alpha/2.md"))])
        XCTAssertEqual(retriever.stats(for: "beta").chunksCount, 1)

        // Conversas isoladas
        let alphaConvs = try await convStore.list()
        XCTAssertEqual(alphaConvs.first?.title, "Conversa Alpha")
    }

    func testProjectIndexDeletionRemovesFilesAndConversations() async throws {
        var currentSettings = Settings.default
        let settingsStore = InMemorySettingsStore(initial: currentSettings)
        let retriever = ProductionAppRetriever(directoryURL: tempDirectory, settingsStore: settingsStore)
        let convStore = try SQLiteConversationStore(
            databaseURL: tempDirectory.appendingPathComponent("conversations.sqlite"),
            activeProjectIdProvider: { settingsStore.load().activeProjectId }
        )

        try await setupAlphaAndBeta(
            retriever: retriever,
            convStore: convStore,
            settingsStore: settingsStore,
            currentSettings: &currentSettings
        )

        let betaDBURL = retriever.databaseURL(for: "beta")
        XCTAssertTrue(FileManager.default.fileExists(atPath: betaDBURL.path))

        try retriever.deleteIndex(for: "beta")
        try await convStore.deleteAll(forProjectId: "beta")

        XCTAssertFalse(FileManager.default.fileExists(atPath: betaDBURL.path))
        let betaConvsAfter = try await convStore.list()
        XCTAssertTrue(betaConvsAfter.isEmpty)

        currentSettings.activeProjectId = "alpha"
        settingsStore.save(currentSettings)
        let alphaConvsAfter = try await convStore.list()
        XCTAssertEqual(alphaConvsAfter.count, 1)
    }
}
