import Foundation
import Observation

/// Estados da tela de Ajustes conforme o protótipo T03.
enum SettingsScreenState: Equatable, Sendable {
    case padrao
    case erro(message: String)
}

/// ViewModel para a aba Ajustes (T03 Configurações, PRD US-05 e US-07).
/// Isola validações, regras de negócio e comunicação com `SettingsStore` e `SecretStore`.
@MainActor
@Observable
final class SettingsViewModel {
    private(set) var settings: Settings
    var state: SettingsScreenState
    var errorMessage: String?
    private(set) var hasSavedApiKey: Bool
    private(set) var maskedApiKey: String?
    var apiKeyInput: String

    private let settingsStore: any SettingsStore
    private let secretStore: any SecretStore

    init(
        settingsStore: any SettingsStore,
        secretStore: any SecretStore,
        initialState: SettingsScreenState = .padrao
    ) {
        self.settingsStore = settingsStore
        self.secretStore = secretStore
        self.settings = settingsStore.load()
        self.state = initialState
        self.apiKeyInput = ""

        if case let .erro(message) = initialState {
            self.errorMessage = message
        } else {
            self.errorMessage = nil
        }

        if let existing = try? secretStore.get(key: SettingsConstants.llmApiKeySecretKey),
           !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.hasSavedApiKey = true
            self.maskedApiKey = Self.maskApiKey(existing)
        } else {
            self.hasSavedApiKey = false
            self.maskedApiKey = nil
        }
    }

    // MARK: - Propriedades de Apresentação e Ajuste

    var format: AnswerFormat {
        get { settings.format }
        set {
            settings.format = newValue
            settingsStore.save(settings)
        }
    }

    var qaThreshold: Double {
        get { settings.qaThreshold }
        set {
            settings.qaThreshold = min(
                max(newValue, Settings.qaThresholdRange.lowerBound),
                Settings.qaThresholdRange.upperBound
            )
            settingsStore.save(settings)
        }
    }

    var chunkThreshold: Double {
        get { settings.chunkThreshold }
        set {
            settings.chunkThreshold = min(
                max(newValue, Settings.chunkThresholdRange.lowerBound),
                Settings.chunkThresholdRange.upperBound
            )
            settingsStore.save(settings)
        }
    }

    var topK: Int {
        get { settings.topK }
        set {
            settings.topK = min(
                max(newValue, Settings.topKRange.lowerBound),
                Settings.topKRange.upperBound
            )
            settingsStore.save(settings)
        }
    }

    var silenceThreshold: Double {
        get { settings.silenceThreshold }
        set {
            settings.silenceThreshold = min(
                max(newValue, Settings.silenceThresholdRange.lowerBound),
                Settings.silenceThresholdRange.upperBound
            )
            settingsStore.save(settings)
        }
    }

    var qaNotesEnabled: Bool {
        get { settings.qaNotesEnabled }
        set {
            settings.qaNotesEnabled = newValue
            settingsStore.save(settings)
        }
    }

    var documentsEnabled: Bool {
        get { settings.documentsEnabled }
        set {
            settings.documentsEnabled = newValue
            settingsStore.save(settings)
        }
    }

    var codeEnabled: Bool {
        get { settings.codeEnabled }
        set {
            settings.codeEnabled = newValue
            settingsStore.save(settings)
        }
    }

    var appearance: AppearancePreference {
        get { settings.appearance }
        set {
            settings.appearance = newValue
            settingsStore.save(settings)
        }
    }

    var llmProvider: String {
        get { settings.llmProvider }
        set {
            settings.llmProvider = newValue
            settingsStore.save(settings)
        }
    }

    var llmBaseURL: String {
        get { settings.llmBaseURL }
        set {
            settings.llmBaseURL = newValue
            settingsStore.save(settings)
        }
    }

    var llmModel: String {
        get { settings.llmModel }
        set {
            settings.llmModel = newValue
            settingsStore.save(settings)
        }
    }

    // MARK: - Ações de Chave de API (SecretStore)

    func saveApiKey() {
        let trimmed = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            let msg = "Chave recusada pelo provedor. Confira e salve de novo."
            state = .erro(message: msg)
            errorMessage = msg
            return
        }

        do {
            try secretStore.set(key: SettingsConstants.llmApiKeySecretKey, value: trimmed)
            hasSavedApiKey = true
            maskedApiKey = Self.maskApiKey(trimmed)
            apiKeyInput = ""
            errorMessage = nil
            state = .padrao
        } catch {
            let msg = "Chave recusada pelo provedor. Confira e salve de novo."
            state = .erro(message: msg)
            errorMessage = msg
        }
    }

    func removeApiKey() {
        do {
            try secretStore.delete(key: SettingsConstants.llmApiKeySecretKey)
            hasSavedApiKey = false
            maskedApiKey = nil
            apiKeyInput = ""
            errorMessage = nil
            state = .padrao
        } catch {
            let msg = "Não foi possível remover a chave do Keychain."
            state = .erro(message: msg)
            errorMessage = msg
        }
    }

    // MARK: - Restaurar Padrões

    func resetToDefaults() {
        settings = settingsStore.resetToDefaults()
        state = .padrao
        errorMessage = nil
    }

    // MARK: - Mascaramento

    static func maskApiKey(_ key: String) -> String {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if trimmed.count >= 4 {
            let suffix = String(trimmed.suffix(4))
            return "Chave salva ••••\(suffix)"
        }
        return "Chave salva ••••"
    }
}
