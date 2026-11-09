import Foundation
import XCTest
@testable import Teleprompter

private final class FailingSecretStore: SecretStore, @unchecked Sendable {
    var shouldFailSet: Bool = true
    var shouldFailDelete: Bool = true

    func get(key: String) throws -> String? {
        nil
    }

    func set(key: String, value: String) throws {
        if shouldFailSet {
            throw KeychainError.unhandledStatus(errSecInternalComponent)
        }
    }

    func delete(key: String) throws {
        if shouldFailDelete {
            throw KeychainError.unhandledStatus(errSecInternalComponent)
        }
    }
}

private final class FakeOpenRouterAuthService: OpenRouterAuthenticating, @unchecked Sendable {
    var shouldFailExchange: Bool = false
    var returnedKey: String = "sk-or-v1-9988776655444f2a"

    func generatePKCE() -> OpenRouterPKCE {
        OpenRouterPKCE(verifier: "fake_verifier", challenge: "fake_challenge")
    }

    func makeAuthURL(challenge: String) -> URL {
        URL(string: "https://openrouter.ai/auth?code_challenge=\(challenge)")!
    }

    func extractCode(from callbackURL: URL) throws -> String {
        "fake_code_123"
    }

    func exchangeCode(code: String, verifier: String) async throws -> String {
        if shouldFailExchange {
            throw OpenRouterAuthError.httpError(statusCode: 401)
        }
        return returnedKey
    }
}

@MainActor
private final class FakeWebAuthSession: WebAuthenticationSessionProtocol {
    var shouldCancel: Bool = false

    func authenticate(url: URL, callbackURLScheme: String) async throws -> URL {
        if shouldCancel {
            throw OpenRouterAuthError.userCancelled
        }
        return URL(string: "\(callbackURLScheme)://openrouter?code=fake_code_123")!
    }
}

@MainActor
final class SettingsViewModelTests: XCTestCase {
    func testViewModelInitialStateWithDefaults() {
        let settingsStore = InMemorySettingsStore()
        let secretStore = InMemorySecretStore()
        let viewModel = SettingsViewModel(settingsStore: settingsStore, secretStore: secretStore)

        XCTAssertEqual(viewModel.format, .bullets)
        XCTAssertEqual(viewModel.qaThreshold, 0.40)
        XCTAssertEqual(viewModel.chunkThreshold, 0.25)
        XCTAssertEqual(viewModel.topK, 3)
        XCTAssertEqual(viewModel.silenceThreshold, 1.2)
        XCTAssertTrue(viewModel.qaNotesEnabled)
        XCTAssertTrue(viewModel.documentsEnabled)
        XCTAssertTrue(viewModel.codeEnabled)
        XCTAssertEqual(viewModel.appearance, .system)
        XCTAssertFalse(viewModel.hasSavedApiKey)
        XCTAssertNil(viewModel.maskedApiKey)
        XCTAssertEqual(viewModel.state, .padrao)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testSaveApiKeyStoresInSecretStoreMasksAndNeverExposesRawKey() throws {
        let settingsStore = InMemorySettingsStore()
        let secretStore = InMemorySecretStore()
        let viewModel = SettingsViewModel(settingsStore: settingsStore, secretStore: secretStore)

        let secretRaw = "sk-live-test123456784f2a"
        viewModel.apiKeyInput = secretRaw
        viewModel.saveApiKey()

        XCTAssertTrue(viewModel.hasSavedApiKey)
        XCTAssertEqual(viewModel.maskedApiKey, "Chave salva ••••4f2a")
        XCTAssertEqual(viewModel.apiKeyInput, "")
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.state, .padrao)

        let savedSecret = try secretStore.get(key: SettingsConstants.llmApiKeySecretKey)
        XCTAssertEqual(savedSecret, secretRaw)

        // Verifica que o raw não está em nenhuma propriedade do ViewModel
        XCTAssertNotEqual(viewModel.maskedApiKey, secretRaw)
        XCTAssertFalse(viewModel.maskedApiKey?.contains("sk-live-test") ?? true)

        // Ao reinicializar outro ViewModel com o secretStore populado:
        let secondViewModel = SettingsViewModel(settingsStore: settingsStore, secretStore: secretStore)
        XCTAssertTrue(secondViewModel.hasSavedApiKey)
        XCTAssertEqual(secondViewModel.maskedApiKey, "Chave salva ••••4f2a")
        XCTAssertEqual(secondViewModel.apiKeyInput, "")
    }

    func testRemoveApiKeyDeletesFromSecretStore() throws {
        let settingsStore = InMemorySettingsStore()
        let secretStore = InMemorySecretStore()
        let viewModel = SettingsViewModel(settingsStore: settingsStore, secretStore: secretStore)

        viewModel.apiKeyInput = "sk-proj-9988776655443322"
        viewModel.saveApiKey()
        XCTAssertTrue(viewModel.hasSavedApiKey)

        viewModel.removeApiKey()
        XCTAssertFalse(viewModel.hasSavedApiKey)
        XCTAssertNil(viewModel.maskedApiKey)
        XCTAssertEqual(viewModel.state, .padrao)
        XCTAssertNil(viewModel.errorMessage)

        let retrieved = try secretStore.get(key: SettingsConstants.llmApiKeySecretKey)
        XCTAssertNil(retrieved)
    }

    func testSecretStoreFailureTransitionsToErrorState() {
        let settingsStore = InMemorySettingsStore()
        let failingSecrets = FailingSecretStore()
        let viewModel = SettingsViewModel(settingsStore: settingsStore, secretStore: failingSecrets)

        viewModel.apiKeyInput = "sk-invalid-or-failing"
        viewModel.saveApiKey()

        XCTAssertFalse(viewModel.hasSavedApiKey)
        XCTAssertEqual(
            viewModel.state,
            .erro(message: "Chave recusada pelo provedor. Confira e salve de novo.")
        )
        XCTAssertEqual(viewModel.errorMessage, "Chave recusada pelo provedor. Confira e salve de novo.")
    }

    func testEmptyApiKeyInputTransitionsToErrorState() {
        let settingsStore = InMemorySettingsStore()
        let secretStore = InMemorySecretStore()
        let viewModel = SettingsViewModel(settingsStore: settingsStore, secretStore: secretStore)

        viewModel.apiKeyInput = "   "
        viewModel.saveApiKey()

        XCTAssertFalse(viewModel.hasSavedApiKey)
        XCTAssertEqual(
            viewModel.state,
            .erro(message: "Chave recusada pelo provedor. Confira e salve de novo.")
        )
    }

    func testRestoreDefaultsResetsAllFields() {
        let settingsStore = InMemorySettingsStore()
        let secretStore = InMemorySecretStore()
        let viewModel = SettingsViewModel(settingsStore: settingsStore, secretStore: secretStore)

        viewModel.format = .keywords
        viewModel.qaThreshold = 0.70
        viewModel.chunkThreshold = 0.50
        viewModel.topK = 8
        viewModel.silenceThreshold = 3.0
        viewModel.qaNotesEnabled = false
        viewModel.documentsEnabled = false
        viewModel.codeEnabled = false
        viewModel.appearance = .dark

        XCTAssertEqual(viewModel.format, .keywords)
        XCTAssertEqual(viewModel.qaThreshold, 0.70)
        XCTAssertEqual(viewModel.appearance, .dark)

        viewModel.resetToDefaults()

        XCTAssertEqual(viewModel.format, .bullets)
        XCTAssertEqual(viewModel.qaThreshold, 0.40)
        XCTAssertEqual(viewModel.chunkThreshold, 0.25)
        XCTAssertEqual(viewModel.topK, 3)
        XCTAssertEqual(viewModel.silenceThreshold, 1.2)
        XCTAssertTrue(viewModel.qaNotesEnabled)
        XCTAssertTrue(viewModel.documentsEnabled)
        XCTAssertTrue(viewModel.codeEnabled)
        XCTAssertEqual(viewModel.appearance, .system)
        XCTAssertEqual(viewModel.state, .padrao)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testThresholdClampingInViewModel() {
        let settingsStore = InMemorySettingsStore()
        let secretStore = InMemorySecretStore()
        let viewModel = SettingsViewModel(settingsStore: settingsStore, secretStore: secretStore)

        viewModel.qaThreshold = 5.0
        XCTAssertEqual(viewModel.qaThreshold, 1.0)

        viewModel.qaThreshold = -2.0
        XCTAssertEqual(viewModel.qaThreshold, 0.0)

        viewModel.chunkThreshold = 3.0
        XCTAssertEqual(viewModel.chunkThreshold, 1.0)

        viewModel.chunkThreshold = -0.5
        XCTAssertEqual(viewModel.chunkThreshold, 0.0)

        viewModel.topK = 99
        XCTAssertEqual(viewModel.topK, 10)

        viewModel.topK = -10
        XCTAssertEqual(viewModel.topK, 1)

        viewModel.silenceThreshold = 20.0
        XCTAssertEqual(viewModel.silenceThreshold, 5.0)

        viewModel.silenceThreshold = 0.1
        XCTAssertEqual(viewModel.silenceThreshold, 0.5)
    }

    func testAnswerFormatMappingChangesOutputFormatInLensFormatterAndPipeline() async throws {
        let formatter = LensFormatter()
        let sampleAnswer = "Primeiro ponto importante. Segundo ponto crucial. Terceiro ponto final."

        let bulletFormatted = formatter.format(sampleAnswer, as: .bullets)
        XCTAssertTrue(bulletFormatted.contains("• "), "Bullets format deve conter marcadores de bullet")

        let keywordsFormatted = formatter.format(sampleAnswer, as: .keywords)
        XCTAssertFalse(keywordsFormatted.contains("• "), "Keywords format não deve conter marcadores de bullet")

        let fullTextFormatted = formatter.format(sampleAnswer, as: .fullText)
        XCTAssertFalse(fullTextFormatted.contains("• "), "FullText format não deve conter marcadores de bullet")

        // Verificação através do AnswerPipeline com os diferentes formatos
        let fakeRetriever = InMemoryAppRetriever()
        let fakeGenerator = InMemoryAppGenerator()
        let fakeLens = SimulatedLens()

        var pipeline = AnswerPipeline(
            retriever: fakeRetriever,
            generator: fakeGenerator,
            formatter: formatter,
            lens: fakeLens,
            format: .bullets
        )
        let bulletResult = try await pipeline.ask("Como funciona a busca?")
        XCTAssertTrue(bulletResult.formattedBody.contains("• "))

        pipeline.format = .fullText
        let fullTextResult = try await pipeline.ask("Como funciona a busca?")
        XCTAssertFalse(fullTextResult.formattedBody.contains("• "))

        // Verificação no ConversationViewModel
        let transcriber = InMemoryAppTranscriber()
        let conversationVM = ConversationViewModel(
            retriever: fakeRetriever,
            generator: fakeGenerator,
            formatter: formatter,
            lens: fakeLens,
            transcriber: transcriber,
            format: .bullets
        )
        XCTAssertEqual(conversationVM.format, .bullets)

        conversationVM.format = .keywords
        XCTAssertEqual(conversationVM.format, .keywords)
    }
}

// MARK: - Testes de Provedores e OpenRouter

extension SettingsViewModelTests {
    func testProviderAndFormatPropertiesPersistToStore() {
        let settingsStore = InMemorySettingsStore()
        let secretStore = InMemorySecretStore()
        let viewModel = SettingsViewModel(settingsStore: settingsStore, secretStore: secretStore)

        viewModel.llmProvider = "apple"
        XCTAssertEqual(settingsStore.load().llmProvider, "apple")

        viewModel.llmProvider = "custom"
        viewModel.llmFormat = "anthropic"
        XCTAssertEqual(settingsStore.load().llmProvider, "custom")
        XCTAssertEqual(settingsStore.load().llmFormat, "anthropic")
    }

    func testOpenRouterLoginSuccessFlow() async throws {
        let settingsStore = InMemorySettingsStore()
        let secretStore = InMemorySecretStore()
        let fakeAuth = FakeOpenRouterAuthService()
        let fakeWeb = FakeWebAuthSession()

        let viewModel = SettingsViewModel(
            settingsStore: settingsStore,
            secretStore: secretStore,
            authService: fakeAuth,
            webAuthSession: fakeWeb
        )

        XCTAssertFalse(viewModel.hasSavedOpenRouterApiKey)
        XCTAssertNil(viewModel.maskedOpenRouterApiKey)

        await viewModel.startOpenRouterLogin()

        XCTAssertTrue(viewModel.hasSavedOpenRouterApiKey)
        XCTAssertEqual(viewModel.maskedOpenRouterApiKey, "Chave no Keychain ••••4f2a")
        XCTAssertEqual(viewModel.state, .padrao)
        XCTAssertNil(viewModel.errorMessage)

        let saved = try secretStore.get(key: SettingsConstants.openRouterApiKeySecretKey)
        XCTAssertEqual(saved, "sk-or-v1-9988776655444f2a")
    }

    func testOpenRouterLoginFailureWhenUserCancels() async {
        let settingsStore = InMemorySettingsStore()
        let secretStore = InMemorySecretStore()
        let fakeAuth = FakeOpenRouterAuthService()
        let fakeWeb = FakeWebAuthSession()
        fakeWeb.shouldCancel = true

        let viewModel = SettingsViewModel(
            settingsStore: settingsStore,
            secretStore: secretStore,
            authService: fakeAuth,
            webAuthSession: fakeWeb
        )

        await viewModel.startOpenRouterLogin()

        XCTAssertFalse(viewModel.hasSavedOpenRouterApiKey)
        XCTAssertEqual(viewModel.state, .erro(message: "Login cancelado ou recusado. Tente de novo."))
        XCTAssertEqual(viewModel.errorMessage, "Login cancelado ou recusado. Tente de novo.")
    }

    func testOpenRouterLoginFailureWhenExchangeFails() async {
        let settingsStore = InMemorySettingsStore()
        let secretStore = InMemorySecretStore()
        let fakeAuth = FakeOpenRouterAuthService()
        fakeAuth.shouldFailExchange = true
        let fakeWeb = FakeWebAuthSession()

        let viewModel = SettingsViewModel(
            settingsStore: settingsStore,
            secretStore: secretStore,
            authService: fakeAuth,
            webAuthSession: fakeWeb
        )

        await viewModel.startOpenRouterLogin()

        XCTAssertFalse(viewModel.hasSavedOpenRouterApiKey)
        XCTAssertEqual(viewModel.state, .erro(message: "Login cancelado ou recusado. Tente de novo."))
        XCTAssertEqual(viewModel.errorMessage, "Login cancelado ou recusado. Tente de novo.")
    }

    func testRemoveOpenRouterApiKeyDeletesFromSecretStore() throws {
        let settingsStore = InMemorySettingsStore()
        let secretStore = InMemorySecretStore(
            initial: [SettingsConstants.openRouterApiKeySecretKey: "sk-or-v1-key1234"]
        )
        let viewModel = SettingsViewModel(settingsStore: settingsStore, secretStore: secretStore)

        XCTAssertTrue(viewModel.hasSavedOpenRouterApiKey)
        XCTAssertEqual(viewModel.maskedOpenRouterApiKey, "Chave no Keychain ••••1234")

        viewModel.removeOpenRouterApiKey()

        XCTAssertFalse(viewModel.hasSavedOpenRouterApiKey)
        XCTAssertNil(viewModel.maskedOpenRouterApiKey)
        XCTAssertNil(try secretStore.get(key: SettingsConstants.openRouterApiKeySecretKey))
    }

    func testAppleSupportedReflectsFoundationModelsSupport() {
        let settingsStore = InMemorySettingsStore()
        let secretStore = InMemorySecretStore()
        let viewModel = SettingsViewModel(settingsStore: settingsStore, secretStore: secretStore)

        XCTAssertEqual(viewModel.isAppleSupported, FoundationModelsAnswerGenerator.isSupported)
    }
}
