import Foundation
import XCTest
@testable import Teleprompter

@MainActor
final class AppEnvironmentIntegrationTests: XCTestCase {
    var tempDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TeleprompterTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        try await super.tearDown()
    }

    func testLegacySettingsJSONDecodesWithEmptyLLMFields() throws {
        let legacyJSON = """
        {
            "format": "bullets",
            "qaThreshold": 0.45,
            "chunkThreshold": 0.30,
            "topK": 4,
            "silenceThreshold": 1.5,
            "qaNotesEnabled": true,
            "documentsEnabled": true,
            "codeEnabled": false,
            "appearance": "dark"
        }
        """

        let data = try XCTUnwrap(legacyJSON.data(using: .utf8))
        let decoded = try JSONDecoder().decode(Settings.self, from: data)

        XCTAssertEqual(decoded.format, .bullets)
        XCTAssertEqual(decoded.qaThreshold, 0.45)
        XCTAssertEqual(decoded.chunkThreshold, 0.30)
        XCTAssertEqual(decoded.topK, 4)
        XCTAssertEqual(decoded.silenceThreshold, 1.5)
        XCTAssertTrue(decoded.qaNotesEnabled)
        XCTAssertTrue(decoded.documentsEnabled)
        XCTAssertFalse(decoded.codeEnabled)
        XCTAssertEqual(decoded.appearance, .dark)
        XCTAssertEqual(decoded.llmBaseURL, "")
        XCTAssertEqual(decoded.llmModel, "")
        XCTAssertEqual(decoded.llmProvider, "openrouter")
        XCTAssertEqual(decoded.llmFormat, "openai")
    }

    func testMakeGeneratorAppleBranch() {
        let secretStore = InMemorySecretStore()
        var settings = Settings.default
        settings.llmProvider = "apple"

        FoundationModelsAnswerGenerator.isSupportedOverride = false
        defer { FoundationModelsAnswerGenerator.isSupportedOverride = nil }
        XCTAssertNil(AppEnvironment.makeGenerator(settings: settings, secretStore: secretStore))

        FoundationModelsAnswerGenerator.isSupportedOverride = true
        let generator = AppEnvironment.makeGenerator(settings: settings, secretStore: secretStore)
        XCTAssertNotNil(generator)
        XCTAssertTrue(generator is FoundationModelsAnswerGenerator)
    }

    func testMakeGeneratorOpenRouterBranch() throws {
        let secretStore = InMemorySecretStore()
        var settings = Settings.default
        settings.llmProvider = "openrouter"

        // Sem chave no Keychain retorna nil
        XCTAssertNil(AppEnvironment.makeGenerator(settings: settings, secretStore: secretStore))

        // Com chave no Keychain do OpenRouter, usa modelo padrão anthropic/claude-haiku se vazio
        try secretStore.set(key: SettingsConstants.openRouterApiKeySecretKey, value: "sk-or-v1-testkey")
        let defaultGen = AppEnvironment.makeGenerator(settings: settings, secretStore: secretStore)
        XCTAssertNotNil(defaultGen)
        let streamingDefault = try XCTUnwrap(defaultGen as? StreamingAnswerGenerator)
        XCTAssertEqual(streamingDefault.baseURL.absoluteString, "https://openrouter.ai/api/v1")
        XCTAssertEqual(streamingDefault.format, .openAI)
        XCTAssertEqual(streamingDefault.model, "anthropic/claude-haiku")
        XCTAssertEqual(streamingDefault.apiKeyKey, SettingsConstants.openRouterApiKeySecretKey)

        // Modelo editável
        settings.llmModel = "openai/gpt-4o-mini"
        let customModelGen = AppEnvironment.makeGenerator(settings: settings, secretStore: secretStore)
        let streamingCustom = try XCTUnwrap(customModelGen as? StreamingAnswerGenerator)
        XCTAssertEqual(streamingCustom.model, "openai/gpt-4o-mini")
    }

    func testMakeGeneratorCustomBranch() throws {
        let secretStore = InMemorySecretStore()
        var settings = Settings.default
        settings.llmProvider = "custom"

        XCTAssertNil(AppEnvironment.makeGenerator(settings: settings, secretStore: secretStore))

        try secretStore.set(key: SettingsConstants.llmApiKeySecretKey, value: "sk-test-12345")
        XCTAssertNil(AppEnvironment.makeGenerator(settings: settings, secretStore: secretStore))

        settings.llmBaseURL = "https://api.openai.com/v1"
        XCTAssertNil(AppEnvironment.makeGenerator(settings: settings, secretStore: secretStore))

        settings.llmModel = "gpt-4o-mini"
        settings.llmFormat = "openai"
        let openAIGen = AppEnvironment.makeGenerator(settings: settings, secretStore: secretStore)
        XCTAssertNotNil(openAIGen)
        let streamingOpenAI = try XCTUnwrap(openAIGen as? StreamingAnswerGenerator)
        XCTAssertEqual(streamingOpenAI.format, .openAI)
        XCTAssertEqual(streamingOpenAI.model, "gpt-4o-mini")
        XCTAssertEqual(streamingOpenAI.apiKeyKey, SettingsConstants.llmApiKeySecretKey)

        settings.llmFormat = "anthropic"
        settings.llmBaseURL = "https://api.anthropic.com/v1"
        settings.llmModel = "claude-3-5-haiku-20241022"
        let anthropicGen = AppEnvironment.makeGenerator(settings: settings, secretStore: secretStore)
        XCTAssertNotNil(anthropicGen)
        let streamingAnthropic = try XCTUnwrap(anthropicGen as? StreamingAnswerGenerator)
        XCTAssertEqual(streamingAnthropic.format, .anthropic)
        XCTAssertEqual(streamingAnthropic.model, "claude-3-5-haiku-20241022")
    }

    func testAppEnvironmentPreviewUsesFakes() {
        let previewEnv = AppEnvironment.preview()
        XCTAssertNotNil(previewEnv.conversationViewModel)
        XCTAssertNotNil(previewEnv.materialViewModel)
        XCTAssertNotNil(previewEnv.settingsViewModel)
        XCTAssertNotNil(previewEnv.conversationsViewModel)
    }

    func testAppEnvironmentProductionWiresUpRealComponents() {
        let prodEnv = AppEnvironment.production()
        XCTAssertNotNil(prodEnv.conversationViewModel)
        XCTAssertNotNil(prodEnv.materialViewModel)
        XCTAssertNotNil(prodEnv.settingsViewModel)
        XCTAssertNotNil(prodEnv.conversationsViewModel)
    }
}

// MARK: - Q&A e Fallback sem LLM

extension AppEnvironmentIntegrationTests {
    func testCompositionWithoutLLMAnswersQANoteDirectly() async throws {
        let dbURL = tempDirectory.appendingPathComponent("retriever.sqlite")
        let settingsStore = InMemorySettingsStore()
        let secretStore = InMemorySecretStore()
        let retriever = ProductionAppRetriever(databaseURL: dbURL, settingsStore: settingsStore)

        let qaChunk = IndexedChunk(
            kind: .qa,
            text: "Swift nativo tem menor latência de áudio.",
            source: SourceRef(path: "qa/swift.md"),
            question: "Por que Swift?"
        )
        try retriever.index([qaChunk])

        let fakeGen = FakeGenerator()
        let viewModel = ConversationViewModel(
            retriever: retriever, generator: fakeGen,
            formatter: LensFormatter(), lens: SimulatedLens(),
            transcriber: InMemoryAppTranscriber(),
            settingsStore: settingsStore, secretStore: secretStore
        )

        await viewModel.ask("Por que Swift?")

        XCTAssertEqual(viewModel.state, .respondido)
        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertTrue(viewModel.messages[0].answer.contains("Swift nativo tem menor latência"))
        XCTAssertEqual(fakeGen.calls, 0, "LLM não deve ser chamado para nota de Q&A")
    }

    func testCompositionWithoutLLMFallsBackToNotFoundWithoutCallingLLMAndWithoutError() async throws {
        let dbURL = tempDirectory.appendingPathComponent("retriever.sqlite")
        let settingsStore = InMemorySettingsStore()
        let secretStore = InMemorySecretStore()
        let retriever = ProductionAppRetriever(databaseURL: dbURL, settingsStore: settingsStore)

        let docChunk = IndexedChunk(
            kind: .document,
            text: "O Teleprompter resolve o problema da banca.",
            source: SourceRef(path: "README.md")
        )
        try retriever.index([docChunk])

        let fakeGen = FakeGenerator()
        let lens = SimulatedLens()
        let viewModel = ConversationViewModel(
            retriever: retriever, generator: fakeGen,
            formatter: LensFormatter(), lens: lens,
            transcriber: InMemoryAppTranscriber(),
            settingsStore: settingsStore, secretStore: secretStore
        )

        await viewModel.ask("Qual problema o app resolve?")

        XCTAssertEqual(viewModel.state, .semMaterial)
        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages[0].answer, AnswerPipeline.notFoundMessage)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(fakeGen.calls, 0, "Sem chave LLM, gerador não pode ser chamado")
        XCTAssertTrue(lens.content?.body.contains("Não encontrei isso no seu") == true)
    }
}

// MARK: - Material e Ajustes

extension AppEnvironmentIntegrationTests {
    func testMaterialImportedInMaterialViewModelIsFoundByChat() async throws {
        let dbURL = tempDirectory.appendingPathComponent("retriever.sqlite")
        let settingsStore = InMemorySettingsStore()
        let secretStore = InMemorySecretStore()
        let retriever = ProductionAppRetriever(databaseURL: dbURL, settingsStore: settingsStore)

        let materialVM = MaterialViewModel(indexable: retriever)
        let chatVM = ConversationViewModel(
            retriever: retriever, generator: FakeGenerator(),
            formatter: LensFormatter(), lens: SimulatedLens(),
            transcriber: InMemoryAppTranscriber(),
            settingsStore: settingsStore, secretStore: secretStore
        )

        let qaContent = """
        Pergunta: Por que não Flutter?
        Resposta: O DAT SDK da Meta só possui bindings em Swift nativo.
        """
        await materialVM.importContent(name: "qa.md", content: qaContent)
        XCTAssertEqual(materialVM.sources.count, 1)

        await chatVM.ask("Por que não Flutter?")

        XCTAssertEqual(chatVM.state, .respondido)
        XCTAssertEqual(chatVM.messages.count, 1)
        XCTAssertTrue(chatVM.messages[0].answer.contains("DAT SDK da Meta só possui bindings em Swift"))
    }

    func testSettingsFormatAndThresholdsAffectNextQuestion() async throws {
        let dbURL = tempDirectory.appendingPathComponent("retriever.sqlite")
        let settingsStore = InMemorySettingsStore()
        let secretStore = InMemorySecretStore()
        let retriever = ProductionAppRetriever(databaseURL: dbURL, settingsStore: settingsStore)

        let qaChunk = IndexedChunk(
            kind: .qa,
            text: "• Monolito modular em Swift\n• UI em SwiftUI puro",
            source: SourceRef(path: "qa/arquitetura.md"),
            question: "Qual a arquitetura do projeto?"
        )
        try retriever.index([qaChunk])

        let lens = SimulatedLens()
        let chatVM = ConversationViewModel(
            retriever: retriever, generator: FakeGenerator(),
            formatter: LensFormatter(), lens: lens,
            transcriber: InMemoryAppTranscriber(),
            settingsStore: settingsStore, secretStore: secretStore
        )

        await chatVM.ask("Qual a arquitetura do projeto?")
        XCTAssertEqual(chatVM.state, .respondido)
        let firstLensBody = try XCTUnwrap(lens.content?.body)
        XCTAssertTrue(firstLensBody.contains("•"))

        var currentSettings = settingsStore.load()
        currentSettings.format = .keywords
        settingsStore.save(currentSettings)

        await chatVM.ask("Qual a arquitetura do projeto?")
        let secondLensBody = try XCTUnwrap(lens.content?.body)
        XCTAssertFalse(secondLensBody.contains("•"))

        currentSettings.qaThreshold = 0.99
        settingsStore.save(currentSettings)

        await chatVM.ask("Qual a arquitetura do projeto?")
        XCTAssertEqual(chatVM.state, .semMaterial)
        XCTAssertEqual(chatVM.messages.last?.answer, AnswerPipeline.notFoundMessage)
    }
}

// MARK: - Microfone e Conversas

extension AppEnvironmentIntegrationTests {
    func testMicrophoneAssetNotInstalledTransitionsToErrorState() async throws {
        let settingsStore = InMemorySettingsStore()
        let secretStore = InMemorySecretStore()
        let fakeAssetManager = FakeSpeechAssetManager(installedLocales: [])

        let chatVM = ConversationViewModel(
            retriever: InMemoryAppRetriever(), generator: FakeGenerator(),
            formatter: LensFormatter(), lens: SimulatedLens(),
            transcriber: InMemoryAppTranscriber(),
            settingsStore: settingsStore, secretStore: secretStore,
            audioSource: MicrophoneAudioSource(),
            speechAssetManager: fakeAssetManager
        )

        chatVM.toggleListening()

        for _ in 0..<50 {
            if chatVM.state == .erro { break }
            await Task.yield()
        }

        XCTAssertEqual(chatVM.state, .erro)
        XCTAssertFalse(chatVM.isListening)
        let errorMsg = try XCTUnwrap(chatVM.errorMessage)
        XCTAssertTrue(errorMsg.localizedCaseInsensitiveContains("instalado") || errorMsg.localizedCaseInsensitiveContains("fala"))

        let screenState = ChatScreenState(from: chatVM)
        XCTAssertEqual(screenState.kind, .erro)
        XCTAssertNotNil(screenState.banner)
    }

    func testConversationStoreSavesQuestionAndAnswerAndReopeningLoadsIt() async throws {
        let store = InMemoryConversationStore()
        let settingsStore = InMemorySettingsStore()
        let secretStore = InMemorySecretStore()

        let chatVM = ConversationViewModel(
            retriever: InMemoryAppRetriever(), generator: InMemoryAppGenerator(),
            formatter: LensFormatter(), lens: SimulatedLens(),
            transcriber: InMemoryAppTranscriber(),
            settingsStore: settingsStore, secretStore: secretStore,
            conversationStore: store
        )

        await chatVM.ask("Por que Swift nativo?")

        for _ in 0..<50 {
            let list = try await store.list()
            if !list.isEmpty && list[0].messages.count >= 2 { break }
            await Task.yield()
        }

        let savedList = try await store.list()
        XCTAssertEqual(savedList.count, 1)
        let savedConv = savedList[0]
        XCTAssertEqual(savedConv.messages.count, 2)
        XCTAssertEqual(savedConv.messages[0].role, .question)
        XCTAssertEqual(savedConv.messages[0].text, "Por que Swift nativo?")
        XCTAssertEqual(savedConv.messages[1].role, .answer)
        XCTAssertTrue(savedConv.messages[1].text.contains("DAT SDK"))
        XCTAssertNotNil(savedConv.messages[1].latencyMs)

        let secondChatVM = ConversationViewModel(
            retriever: InMemoryAppRetriever(), generator: InMemoryAppGenerator(),
            formatter: LensFormatter(), lens: SimulatedLens(),
            transcriber: InMemoryAppTranscriber(),
            settingsStore: settingsStore, secretStore: secretStore,
            conversationStore: store
        )
        secondChatVM.loadConversation(savedConv)

        XCTAssertEqual(secondChatVM.state, .respondido)
        XCTAssertEqual(secondChatVM.messages.count, 1)
        XCTAssertEqual(secondChatVM.messages[0].question, "Por que Swift nativo?")
        XCTAssertEqual(secondChatVM.messages[0].answer, savedConv.messages[1].text)
        XCTAssertEqual(secondChatVM.currentConversationId, savedConv.id)
    }
}
