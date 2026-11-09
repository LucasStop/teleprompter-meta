import Foundation

extension AnswerFormat: Codable {}

/// Preferência de tema da aplicação.
enum AppearancePreference: String, Sendable, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "Sistema"
        case .light: return "Claro"
        case .dark: return "Escuro"
        }
    }
}

/// Extensão de apresentação amigável para `AnswerFormat`.
extension AnswerFormat {
    var title: String {
        switch self {
        case .bullets: return "Bullets"
        case .keywords: return "Palavras-chave"
        case .fullText: return "Texto"
        }
    }
}

/// Constantes do domínio de configurações e persistência.
enum SettingsConstants {
    /// Chave do Keychain para a chave de API do LLM (ADR-005).
    static let llmApiKeySecretKey = "llm.apiKey"
    /// Chave do UserDefaults para preferências não secretas.
    static let userDefaultsSettingsKey = "br.com.lucasstop.teleprompter.settings"
}

/// Entidade de configurações do app (docs/DATA.md e PRD US-07).
struct Settings: Sendable, Codable, Equatable {
    var format: AnswerFormat
    var qaThreshold: Double
    var chunkThreshold: Double
    var topK: Int
    var silenceThreshold: Double
    var qaNotesEnabled: Bool
    var documentsEnabled: Bool
    var codeEnabled: Bool
    var appearance: AppearancePreference

    static let defaultQAThreshold: Double = 0.40
    static let defaultChunkThreshold: Double = 0.25
    static let defaultTopK: Int = 3
    static let defaultSilenceThreshold: Double = 1.2

    static let qaThresholdRange: ClosedRange<Double> = 0.0...1.0
    static let chunkThresholdRange: ClosedRange<Double> = 0.0...1.0
    static let topKRange: ClosedRange<Int> = 1...10
    static let silenceThresholdRange: ClosedRange<Double> = 0.5...5.0

    static let `default` = Settings(
        format: .bullets,
        qaThreshold: defaultQAThreshold,
        chunkThreshold: defaultChunkThreshold,
        topK: defaultTopK,
        silenceThreshold: defaultSilenceThreshold,
        qaNotesEnabled: true,
        documentsEnabled: true,
        codeEnabled: true,
        appearance: .system
    )

    init(
        format: AnswerFormat = .bullets,
        qaThreshold: Double = defaultQAThreshold,
        chunkThreshold: Double = defaultChunkThreshold,
        topK: Int = defaultTopK,
        silenceThreshold: Double = defaultSilenceThreshold,
        qaNotesEnabled: Bool = true,
        documentsEnabled: Bool = true,
        codeEnabled: Bool = true,
        appearance: AppearancePreference = .system
    ) {
        self.format = format
        self.qaThreshold = qaThreshold
        self.chunkThreshold = chunkThreshold
        self.topK = topK
        self.silenceThreshold = silenceThreshold
        self.qaNotesEnabled = qaNotesEnabled
        self.documentsEnabled = documentsEnabled
        self.codeEnabled = codeEnabled
        self.appearance = appearance
    }

    /// Garante que os limiares estejam dentro de faixas válidas.
    func clamped() -> Settings {
        var copy = self
        copy.qaThreshold = min(max(copy.qaThreshold, Self.qaThresholdRange.lowerBound), Self.qaThresholdRange.upperBound)
        copy.chunkThreshold = min(
            max(copy.chunkThreshold, Self.chunkThresholdRange.lowerBound),
            Self.chunkThresholdRange.upperBound
        )
        copy.topK = min(max(copy.topK, Self.topKRange.lowerBound), Self.topKRange.upperBound)
        copy.silenceThreshold = min(
            max(copy.silenceThreshold, Self.silenceThresholdRange.lowerBound),
            Self.silenceThresholdRange.upperBound
        )
        return copy
    }
}

/// Protocolo de persistência para configurações não sensíveis (PRD US-07).
protocol SettingsStore: Sendable {
    func load() -> Settings
    func save(_ settings: Settings)
    @discardableResult
    func resetToDefaults() -> Settings
}

/// Implementação do `SettingsStore` com `UserDefaults` e suporte a suite isolada.
final class UserDefaultsSettingsStore: SettingsStore, @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let storageKey: String
    private let lock = NSLock()

    init(
        suiteName: String? = nil,
        storageKey: String = SettingsConstants.userDefaultsSettingsKey
    ) {
        if let suiteName {
            self.userDefaults = UserDefaults(suiteName: suiteName) ?? .standard
        } else {
            self.userDefaults = .standard
        }
        self.storageKey = storageKey
    }

    init(
        userDefaults: UserDefaults,
        storageKey: String = SettingsConstants.userDefaultsSettingsKey
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
    }

    func load() -> Settings {
        lock.lock()
        defer { lock.unlock() }

        guard let data = userDefaults.data(forKey: storageKey) else {
            return .default
        }
        do {
            let decoded = try JSONDecoder().decode(Settings.self, from: data)
            return decoded.clamped()
        } catch {
            return .default
        }
    }

    func save(_ settings: Settings) {
        lock.lock()
        defer { lock.unlock() }

        let clamped = settings.clamped()
        if let encoded = try? JSONEncoder().encode(clamped) {
            userDefaults.set(encoded, forKey: storageKey)
        }
    }

    @discardableResult
    func resetToDefaults() -> Settings {
        lock.lock()
        defer { lock.unlock() }

        let standard = Settings.default
        if let encoded = try? JSONEncoder().encode(standard) {
            userDefaults.set(encoded, forKey: storageKey)
        }
        return standard
    }
}

/// Implementação em memória para testes e previews rápidos.
final class InMemorySettingsStore: SettingsStore, @unchecked Sendable {
    private let lock = NSLock()
    private var settings: Settings

    init(initial: Settings = .default) {
        self.settings = initial.clamped()
    }

    func load() -> Settings {
        lock.lock()
        defer { lock.unlock() }
        return settings
    }

    func save(_ settings: Settings) {
        lock.lock()
        defer { lock.unlock() }
        self.settings = settings.clamped()
    }

    @discardableResult
    func resetToDefaults() -> Settings {
        lock.lock()
        defer { lock.unlock() }
        self.settings = .default
        return settings
    }
}
