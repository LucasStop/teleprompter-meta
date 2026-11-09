import AVFoundation
import Foundation
import Observation

/// Filtra o retriever para responder exclusivamente notas de Q&A quando não há LLM configurado (ADR-0009).
struct QANoteOnlyRetriever: Retriever, Sendable {
    let underlying: any Retriever

    func retrieve(_ question: String) async throws -> Retrieval {
        let result = try await underlying.retrieve(question)
        if let note = result.qaNote {
            return Retrieval(qaNote: note, chunks: [])
        }
        return Retrieval(qaNote: nil, chunks: [])
    }
}

/// Estados do chat conforme o protótipo T02.
enum ConversationState: String, Sendable, CaseIterable, Equatable {
    case vazio, ouvindo, pensando, respondido, semMaterial, erro, desconectado
}

/// Mensagem de troca no chat (pergunta, resposta, fontes e métricas de latência).
struct ChatMessage: Identifiable, Sendable, Equatable {
    let id: UUID
    var question: String
    var answer: String
    var sources: [SourceRef]
    var latency: LatencyReport?
    var isSourcesExpanded: Bool

    var pergunta: String { question }
    var resposta: String { answer }
    var fontes: [SourceRef] { sources }
    var latencia: LatencyReport? { latency }

    init(
        id: UUID = UUID(),
        question: String,
        answer: String,
        sources: [SourceRef] = [],
        latency: LatencyReport? = nil,
        isSourcesExpanded: Bool = false
    ) {
        self.id = id; self.question = question; self.answer = answer
        self.sources = sources; self.latency = latency
        self.isSourcesExpanded = isSourcesExpanded
    }

    init(
        id: UUID = UUID(),
        pergunta: String,
        resposta: String,
        fontes: [SourceRef] = [],
        latencia: LatencyReport? = nil,
        isSourcesExpanded: Bool = false
    ) {
        self.id = id; self.question = pergunta; self.answer = resposta
        self.sources = fontes; self.latency = latencia
        self.isSourcesExpanded = isSourcesExpanded
    }
}

/// Orquestra a sessão do chat (PRD US-01 a US-06, US-12, US-13, ARCHITECTURE seção 2 e T02).
@MainActor
@Observable
final class ConversationViewModel {
    var messages: [ChatMessage] = []
    var state: ConversationState = .vazio
    var lastLatencyReport: LatencyReport?
    var errorMessage: String?
    var isListening: Bool = false
    var isGlassesConnected: Bool = true
    var currentTranscript: String = ""
    var pendingQuestion: String?
    var lastLensContent: LensContent?
    var currentConversationId: UUID?
    var format: AnswerFormat {
        didSet { pipeline.format = format }
    }

    var hasApiKey: Bool {
        guard let secretStore else { return false }
        if let key = try? secretStore.get(key: SettingsConstants.llmApiKeySecretKey),
           !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        return false
    }

    let retriever: any Retriever
    let generator: any AnswerGenerator
    let formatter: any ResponseFormatter
    let lens: any Lens
    let transcriber: any SpeechTranscriber
    var detector: any QuestionDetector
    let clock: any Clock
    var pipeline: AnswerPipeline

    let settingsStore: (any SettingsStore)?
    let secretStore: (any SecretStore)?
    let conversationStore: (any ConversationStore)?
    let audioSource: (any AudioSource)?
    let speechAssetManager: (any SpeechAssetManager)?
    let generatorProvider: (@Sendable (Settings, any SecretStore) -> (any AnswerGenerator)?)?
    var hasMaterialProvider: (@Sendable () -> Bool)?
    var onProjectChanged: (@MainActor (String) async -> Void)?
    var listenTask: Task<Void, Never>?

    var hasMaterial: Bool {
        if let provider = hasMaterialProvider {
            return provider()
        }
        let activeProj = settingsStore?.load().activeProjectId ?? "default"
        if let prod = retriever as? ProductionAppRetriever {
            return prod.stats(for: activeProj).chunksCount > 0
        }
        if let mem = retriever as? InMemoryAppRetriever {
            return mem.stats(for: activeProj).chunksCount > 0
        }
        return true
    }

    init(
        retriever: any Retriever,
        generator: any AnswerGenerator,
        formatter: any ResponseFormatter = LensFormatter(),
        lens: any Lens,
        transcriber: any SpeechTranscriber,
        detector: any QuestionDetector = PauseQuestionDetector(),
        clock: any Clock = SystemClock(),
        format: AnswerFormat = .bullets,
        settingsStore: (any SettingsStore)? = nil,
        secretStore: (any SecretStore)? = nil,
        conversationStore: (any ConversationStore)? = nil,
        audioSource: (any AudioSource)? = nil,
        speechAssetManager: (any SpeechAssetManager)? = nil,
        generatorProvider: (@Sendable (Settings, any SecretStore) -> (any AnswerGenerator)?)? = nil
    ) {
        self.retriever = retriever
        self.generator = generator
        self.formatter = formatter
        self.lens = lens
        self.transcriber = transcriber
        self.detector = detector
        self.clock = clock
        self.format = format
        self.settingsStore = settingsStore
        self.secretStore = secretStore
        self.conversationStore = conversationStore
        self.audioSource = audioSource
        self.speechAssetManager = speechAssetManager
        self.generatorProvider = generatorProvider
        self.pipeline = AnswerPipeline(
            retriever: retriever, generator: generator,
            formatter: formatter, lens: lens,
            format: format, clock: clock
        )
    }

    func ask(_ text: String) async {
        await handleQuestion(text, sttDuration: nil)
    }

    func toggleListening() {
        if isListening { stopListening() } else { startListening() }
    }

    func clearChat() {
        self.messages = []
        self.currentConversationId = nil
        self.state = .vazio
        self.errorMessage = nil
        self.lastLatencyReport = nil
        self.lastLensContent = nil
        self.currentTranscript = ""
    }

    func switchProject(to projectId: String) async {
        if var settings = settingsStore?.load() {
            settings.activeProjectId = projectId
            settingsStore?.save(settings)
        }
        clearChat()
        if let onProjectChanged {
            await onProjectChanged(projectId)
        }
    }
}

// MARK: - Escuta e Áudio

extension ConversationViewModel {
    func startListening() {
        isListening = true
        state = .ouvindo
        listenTask?.cancel()
        listenTask = Task { [weak self] in
            guard let self else { return }
            await self.beginListening()
        }
    }

    private func beginListening() async {
        if let assetManager = speechAssetManager {
            let locale = Locale(identifier: "pt-BR")
            if await !assetManager.isInstalled(for: locale) {
                self.state = .erro
                self.errorMessage = "Modelo de voz em português (pt-BR) não está instalado. "
                    + "Baixe o pacote de fala em Ajustes do iOS ou aguarde a instalação."
                self.isListening = false
                return
            }
        }

        if AVAudioApplication.shared.recordPermission == .denied {
            self.state = .erro
            self.errorMessage = "Permissão do microfone negada. "
                + "Permita o acesso ao microfone nos Ajustes do iOS para utilizar a escuta."
            self.isListening = false
            return
        }

        guard let audioSource else {
            self.isListening = true
            self.state = .ouvindo
            return
        }

        self.isListening = true
        self.state = .ouvindo
        await self.listen(audioSource.start())
    }

    func stopListening() {
        listenTask?.cancel()
        listenTask = nil
        audioSource?.stop()
        isListening = false
        currentTranscript = ""
        if state == .ouvindo {
            state = messages.isEmpty ? .vazio : .respondido
        }
    }

    func listen(_ audio: AsyncStream<AudioBuffer>) async {
        isListening = true
        state = .ouvindo
        detector.reset()

        var utteranceStart = clock.now()
        var lastUpdateTime = utteranceStart
        var lastText = ""

        for await transcript in transcriber.transcribe(audio) {
            guard !Task.isCancelled && isListening else { break }
            currentTranscript = transcript.text
            let trimmed = transcript.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let now = clock.now()

            let silence: Double
            if trimmed != lastText {
                lastText = trimmed; lastUpdateTime = now; silence = 0.0
            } else {
                silence = lastUpdateTime.duration(to: now).seconds
            }

            if let question = detector.feed(transcript, silenceSeconds: silence) {
                let sttDuration = utteranceStart.duration(to: now)
                currentTranscript = ""
                await handleQuestion(question, sttDuration: sttDuration)
                detector.reset()
                lastText = ""
                utteranceStart = clock.now()
                lastUpdateTime = utteranceStart
            }
        }

        isListening = false
        currentTranscript = ""
        if state == .ouvindo { state = messages.isEmpty ? .vazio : .respondido }
    }
}

// MARK: - Pipeline e Perguntas

extension ConversationViewModel {
    private func resolvePipeline() -> AnswerPipeline {
        let currentSettings = settingsStore?.load()
        if let currentSettings {
            self.format = currentSettings.format
            self.pipeline.format = currentSettings.format
            if detector is PauseQuestionDetector {
                self.detector = PauseQuestionDetector(silenceThreshold: currentSettings.silenceThreshold)
            }
        }

        let resolvedGen: (any AnswerGenerator)?
        if let currentSettings, let secretStore {
            if let generatorProvider {
                resolvedGen = generatorProvider(currentSettings, secretStore)
            } else {
                resolvedGen = AppEnvironment.makeGenerator(settings: currentSettings, secretStore: secretStore)
            }
        } else {
            resolvedGen = self.generator
        }

        let activeGenerator = resolvedGen ?? self.generator
        let activeRetriever: any Retriever = resolvedGen == nil
            ? QANoteOnlyRetriever(underlying: retriever)
            : retriever

        return AnswerPipeline(
            retriever: activeRetriever, generator: activeGenerator,
            formatter: formatter, lens: lens,
            format: self.format, clock: clock
        )
    }

    func handleQuestion(_ question: String, sttDuration: Duration?) async {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state = .pensando
        pendingQuestion = trimmed
        errorMessage = nil
        defer { pendingQuestion = nil }

        let activePipeline = resolvePipeline()

        do {
            let result = try await activePipeline.ask(trimmed, sttDuration: sttDuration)
            lastLatencyReport = result.latency
            lastLensContent = LensContent(question: trimmed, body: result.formattedBody, sources: result.sources)
            let msg = ChatMessage(question: trimmed, answer: result.text, sources: result.sources, latency: result.latency)
            messages.append(msg)
            state = result.isNotFound ? .semMaterial : .respondido

            await saveToConversationStore(question: trimmed, answer: result.text, sources: result.sources, latency: result.latency)
        } catch {
            state = .erro
            errorMessage = actionableErrorMessage(for: error)
        }
    }

    private func actionableErrorMessage(for error: Error) -> String {
        if let localized = error as? LocalizedError, let desc = localized.errorDescription {
            return "\(desc) Tente novamente."
        }
        return "Não foi possível buscar ou gerar a resposta. Verifique a conexão e tente novamente."
    }
}
