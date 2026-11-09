import Foundation
import Observation

/// Recuperador de produção sobre SQLite que responde à atualização de limiares do SettingsStore
/// e atua como índice para o MaterialViewModel.
final class ProductionAppRetriever: Retriever, MaterialIndexable, @unchecked Sendable {
    private let databaseURL: URL
    private let settingsStore: any SettingsStore
    private let lock = NSLock()
    private var cachedRetriever: LocalRetriever?
    private var cachedSettings: Settings?

    init(databaseURL: URL, settingsStore: any SettingsStore) {
        self.databaseURL = databaseURL
        self.settingsStore = settingsStore
    }

    private func getRetriever(for settings: Settings) throws -> LocalRetriever {
        lock.lock()
        defer { lock.unlock() }

        if let cached = cachedRetriever, let oldSettings = cachedSettings,
           oldSettings.qaThreshold == settings.qaThreshold,
           oldSettings.chunkThreshold == settings.chunkThreshold,
           oldSettings.topK == settings.topK {
            return cached
        }

        let retriever = try LocalRetriever(
            databaseURL: databaseURL,
            qaThreshold: settings.qaThreshold,
            chunkThreshold: settings.chunkThreshold,
            topK: settings.topK
        )
        self.cachedRetriever = retriever
        self.cachedSettings = settings
        return retriever
    }

    private func getAnyRetriever() throws -> LocalRetriever {
        let settings = settingsStore.load()
        return try getRetriever(for: settings)
    }

    func index(_ items: [IndexedChunk]) throws {
        let retriever = try getAnyRetriever()
        try retriever.index(items)
    }

    func removeSource(_ path: String) throws {
        let retriever = try getAnyRetriever()
        try retriever.removeSource(path)
    }

    func retrieve(_ question: String) async throws -> Retrieval {
        let settings = settingsStore.load()
        let retriever = try getRetriever(for: settings)
        return try await retriever.retrieve(question)
    }
}

/// Raiz de composição da aplicação Teleprompter (T02).
/// Fabrica a versão de produção com hardware real e SQLite persistente,
/// ou a versão de preview/teste com doubles em memória.
@MainActor
@Observable
final class AppEnvironment {
    let lens: SimulatedLens
    let conversationViewModel: ConversationViewModel
    let conversationStore: any ConversationStore
    let conversationsViewModel: ConversationsViewModel
    let settingsStore: any SettingsStore
    let secretStore: any SecretStore
    let settingsViewModel: SettingsViewModel
    let materialViewModel: MaterialViewModel
    let ensaioViewModel: EnsaioViewModel

    init(
        lens: SimulatedLens = SimulatedLens(),
        conversationViewModel: ConversationViewModel? = nil,
        conversationStore: (any ConversationStore)? = nil,
        conversationsViewModel: ConversationsViewModel? = nil,
        settingsStore: (any SettingsStore)? = nil,
        secretStore: (any SecretStore)? = nil,
        settingsViewModel: SettingsViewModel? = nil,
        materialViewModel: MaterialViewModel? = nil,
        ensaioViewModel: EnsaioViewModel? = nil
    ) {
        self.lens = lens
        let effectiveSettingsStore = settingsStore ?? UserDefaultsSettingsStore()
        let effectiveSecretStore = secretStore ?? KeychainStore()
        self.settingsStore = effectiveSettingsStore
        self.secretStore = effectiveSecretStore

        let store = conversationStore ?? Self.defaultConversationStore()
        self.conversationStore = store
        self.conversationsViewModel = conversationsViewModel ?? ConversationsViewModel(store: store)
        self.settingsViewModel = settingsViewModel ?? SettingsViewModel(
            settingsStore: effectiveSettingsStore,
            secretStore: effectiveSecretStore
        )

        let retrieverDBURL = Self.applicationSupportURL(for: "retriever.sqlite")
        let retriever = ProductionAppRetriever(databaseURL: retrieverDBURL, settingsStore: effectiveSettingsStore)
        self.materialViewModel = materialViewModel ?? MaterialViewModel(indexable: retriever)

        if let ensaioViewModel {
            self.ensaioViewModel = ensaioViewModel
        } else {
            self.ensaioViewModel = Self.makeDefaultEnsaioViewModel(
                retriever: retriever,
                lens: lens,
                settingsStore: effectiveSettingsStore,
                secretStore: effectiveSecretStore
            )
        }

        if let conversationViewModel {
            self.conversationViewModel = conversationViewModel
        } else {
            self.conversationViewModel = Self.makeDefaultConversationViewModel(
                retriever: retriever,
                lens: lens,
                settingsStore: effectiveSettingsStore,
                secretStore: effectiveSecretStore,
                store: store
            )
        }
    }

    private static func applicationSupportURL(for filename: String) -> URL {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let appSupportDir = supportDir.appendingPathComponent("Teleprompter", isDirectory: true)
        if !FileManager.default.fileExists(atPath: appSupportDir.path) {
            try? FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
        }
        return appSupportDir.appendingPathComponent(filename)
    }

    private static func defaultConversationStore() -> any ConversationStore {
        let dbURL = applicationSupportURL(for: "conversations.sqlite")
        return (try? SQLiteConversationStore(databaseURL: dbURL)) ?? InMemoryConversationStore()
    }

    /// Ensaio de produção: transcritor real, mesmo índice do chat e LLM só quando configurado.
    private static func makeDefaultEnsaioViewModel(
        retriever: any Retriever,
        lens: SimulatedLens,
        settingsStore: any SettingsStore,
        secretStore: any SecretStore
    ) -> EnsaioViewModel {
        let assetManager = SystemSpeechAssetManager()
        let generator = makeGenerator(settings: settingsStore.load(), secretStore: secretStore)
        let runner = EnsaioRunner(
            transcriber: SpeechAnalyzerTranscriber(locale: Locale(identifier: "pt-BR"), assetManager: assetManager),
            retriever: generator == nil ? QANoteOnlyRetriever(underlying: retriever) : retriever,
            generator: generator ?? InMemoryAppGenerator(),
            lens: lens,
            speechAssetManager: assetManager
        )
        return EnsaioViewModel(runner: runner)
    }

    private static func makeDefaultConversationViewModel(
        retriever: any Retriever,
        lens: SimulatedLens,
        settingsStore: any SettingsStore,
        secretStore: any SecretStore,
        store: any ConversationStore
    ) -> ConversationViewModel {
        let assetManager = SystemSpeechAssetManager()
        let transcriber = SpeechAnalyzerTranscriber(
            locale: Locale(identifier: "pt-BR"),
            assetManager: assetManager
        )
        let audioSource = MicrophoneAudioSource()
        let settings = settingsStore.load()
        let initialGenerator = makeGenerator(settings: settings, secretStore: secretStore)

        return ConversationViewModel(
            retriever: retriever,
            generator: initialGenerator ?? InMemoryAppGenerator(),
            formatter: LensFormatter(),
            lens: lens,
            transcriber: transcriber,
            detector: PauseQuestionDetector(silenceThreshold: settings.silenceThreshold),
            format: settings.format,
            settingsStore: settingsStore,
            secretStore: secretStore,
            conversationStore: store,
            audioSource: audioSource,
            speechAssetManager: assetManager
        )
    }

    /// Função pura testável que decide e instancia o AnswerGenerator com base nas configurações e segredos.
    /// Retorna `nil` se não houver chave de API ou se baseURL/modelo não estiverem configurados.
    static func makeGenerator(
        settings: Settings,
        secretStore: any SecretStore
    ) -> (any AnswerGenerator)? {
        guard let key = try? secretStore.get(key: SettingsConstants.llmApiKeySecretKey),
              !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        let trimmedBaseURL = settings.llmBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBaseURL.isEmpty,
              let url = URL(string: trimmedBaseURL),
              url.scheme != nil,
              let host = url.host,
              !host.isEmpty else {
            return nil
        }
        let trimmedModel = settings.llmModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedModel.isEmpty else {
            return nil
        }

        let provider = settings.llmProvider.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let format: StreamingAnswerGenerator.Format = provider == "anthropic" ? .anthropic : .openAI

        return StreamingAnswerGenerator(
            baseURL: url,
            model: trimmedModel,
            secretStore: secretStore,
            apiKeyKey: SettingsConstants.llmApiKeySecretKey,
            format: format
        )
    }

    /// Fábrica de produção com componentes reais.
    static func production() -> AppEnvironment {
        AppEnvironment()
    }

    /// Fábrica de preview e testes em memória.
    static func preview() -> AppEnvironment {
        let lens = SimulatedLens()
        let convStore = InMemoryConversationStore()
        let settingsStore = InMemorySettingsStore()
        let secretStore = InMemorySecretStore()
        let retriever = InMemoryAppRetriever()
        let generator = InMemoryAppGenerator()
        let transcriber = InMemoryAppTranscriber()
        let detector = PauseQuestionDetector(silenceThreshold: 1.2)

        let conversationVM = ConversationViewModel(
            retriever: retriever,
            generator: generator,
            formatter: LensFormatter(),
            lens: lens,
            transcriber: transcriber,
            detector: detector,
            format: .bullets,
            settingsStore: settingsStore,
            secretStore: secretStore,
            conversationStore: convStore
        )
        let materialVM = MaterialViewModel(indexable: retriever)
        let settingsVM = SettingsViewModel(settingsStore: settingsStore, secretStore: secretStore)
        let conversationsVM = ConversationsViewModel(store: convStore)

        return AppEnvironment(
            lens: lens,
            conversationViewModel: conversationVM,
            conversationStore: convStore,
            conversationsViewModel: conversationsVM,
            settingsStore: settingsStore,
            secretStore: secretStore,
            settingsViewModel: settingsVM,
            materialViewModel: materialVM
        )
    }

    /// Alias para preview em testes.
    static func test() -> AppEnvironment {
        preview()
    }
}

// MARK: - InMemory Doubles para o AppEnvironment

/// Recuperador em memória com dados mockados para o protótipo da sessão.
struct InMemoryAppRetriever: Retriever, MaterialIndexable, Sendable {
    func index(_ items: [IndexedChunk]) throws {}
    func removeSource(_ path: String) throws {}

    func retrieve(_ question: String) async throws -> Retrieval {
        let lower = question.lowercased()

        if lower.contains("swift") || lower.contains("flutter") {
            let note = Chunk(
                text: "• DAT SDK só tem módulos Swift\n• Menor latência de áudio\n• Acesso direto ao SpeechAnalyzer",
                source: SourceRef(path: "qa/stack.md")
            )
            return Retrieval(qaNote: note, chunks: [])
        }

        if lower.contains("problema") || lower.contains("resolve") {
            let chunk = Chunk(
                text: "• Resposta rápida na banca\n• Sem olhar anotações",
                source: SourceRef(path: "README.md")
            )
            return Retrieval(qaNote: nil, chunks: [chunk])
        }

        if lower.contains("busca") {
            let chunk = Chunk(
                text: "Busca híbrida com BM25 e embeddings locais no dispositivo.",
                source: SourceRef(path: "docs/ADR-0001.md")
            )
            return Retrieval(qaNote: nil, chunks: [chunk])
        }

        // Sem trecho acima do limiar -> US-13
        return Retrieval(qaNote: nil, chunks: [])
    }
}

/// Gerador em memória simulando streaming de tokens.
final class InMemoryAppGenerator: AnswerGenerator, @unchecked Sendable {
    func generate(question: String, context: [Chunk]) -> AsyncStream<String> {
        let text = context.map(\.text).joined(separator: "\n")
        let content = text.isEmpty ? "Resposta gerada a partir do contexto." : text

        return AsyncStream { continuation in
            let words = content.components(separatedBy: " ")
            for (index, word) in words.enumerated() {
                let suffix = index == words.count - 1 ? "" : " "
                continuation.yield(word + suffix)
            }
            continuation.finish()
        }
    }
}

/// Transcritor em memória sem microfone real.
final class InMemoryAppTranscriber: SpeechTranscriber, @unchecked Sendable {
    func transcribe(_ audio: AsyncStream<AudioBuffer>) -> AsyncStream<Transcript> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
}
