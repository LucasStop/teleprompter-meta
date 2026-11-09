import Foundation
import Observation

/// Raiz de composição da aplicação Teleprompter (T02).
/// Monta o ConversationViewModel com dependências em memória (FakeRetriever/FakeGenerator)
/// sem requisições de rede e sem hardware real.
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
        settingsStore: (any SettingsStore)? = nil,
        secretStore: (any SecretStore)? = nil,
        materialViewModel: MaterialViewModel? = nil,
        ensaioViewModel: EnsaioViewModel? = nil
    ) {
        let lensInstance = lens
        self.lens = lensInstance

        let store = Self.resolveConversationStore(conversationStore)
        self.conversationStore = store
        self.conversationsViewModel = ConversationsViewModel(store: store)

        let effectiveSettingsStore: any SettingsStore = settingsStore ?? UserDefaultsSettingsStore()
        let effectiveSecretStore: any SecretStore = secretStore ?? KeychainStore()
        self.settingsStore = effectiveSettingsStore
        self.secretStore = effectiveSecretStore
        self.settingsViewModel = SettingsViewModel(
            settingsStore: effectiveSettingsStore,
            secretStore: effectiveSecretStore
        )

        let retriever = InMemoryAppRetriever()
        if let conversationViewModel {
            self.conversationViewModel = conversationViewModel
        } else {
            let generator = InMemoryAppGenerator()
            let transcriber = InMemoryAppTranscriber()
            let detector = PauseQuestionDetector(silenceThreshold: 1.2)
            self.conversationViewModel = ConversationViewModel(
                retriever: retriever,
                generator: generator,
                formatter: LensFormatter(),
                lens: lensInstance,
                transcriber: transcriber,
                detector: detector,
                format: .bullets
            )
        }

        if let materialViewModel {
            self.materialViewModel = materialViewModel
        } else {
            self.materialViewModel = MaterialViewModel(indexable: retriever)
        }

        if let ensaioViewModel {
            self.ensaioViewModel = ensaioViewModel
        } else {
            let runner = EnsaioRunner(
                transcriber: InMemoryAppTranscriber(),
                retriever: retriever,
                generator: InMemoryAppGenerator(),
                formatter: LensFormatter(),
                lens: lensInstance
            )
            self.ensaioViewModel = EnsaioViewModel(runner: runner)
        }
    }

    private static func resolveConversationStore(_ store: (any ConversationStore)?) -> any ConversationStore {
        if let store { return store }
        guard let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return InMemoryConversationStore()
        }
        let dbURL = supportDir.appendingPathComponent("Teleprompter").appendingPathComponent("conversations.sqlite")
        return (try? SQLiteConversationStore(databaseURL: dbURL)) ?? InMemoryConversationStore()
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
