import Foundation
import Observation

/// Estados do chat conforme o protótipo T02.
enum ConversationState: String, Sendable, CaseIterable, Equatable {
    case vazio
    case ouvindo
    case pensando
    case respondido
    case semMaterial
    case erro
}

/// Mensagem de troca no chat (pergunta, resposta, fontes e métricas de latência).
struct ChatMessage: Identifiable, Sendable, Equatable {
    let id: UUID
    var question: String
    var answer: String
    var sources: [SourceRef]
    var latency: LatencyReport?

    // Conveniência em português
    var pergunta: String { question }
    var resposta: String { answer }
    var fontes: [SourceRef] { sources }
    var latencia: LatencyReport? { latency }

    init(
        id: UUID = UUID(),
        question: String,
        answer: String,
        sources: [SourceRef] = [],
        latency: LatencyReport? = nil
    ) {
        self.id = id
        self.question = question
        self.answer = answer
        self.sources = sources
        self.latency = latency
    }

    init(
        id: UUID = UUID(),
        pergunta: String,
        resposta: String,
        fontes: [SourceRef] = [],
        latencia: LatencyReport? = nil
    ) {
        self.id = id
        self.question = pergunta
        self.answer = resposta
        self.sources = fontes
        self.latency = latencia
    }
}

/// Orquestra a sessão do chat (PRD US-01 a US-06, US-12, US-13, ARCHITECTURE seção 2 e T02).
/// Conecta entradas (texto ou áudio), detecção de pergunta, busca, LLM, formatação e lente.
@MainActor
@Observable
final class ConversationViewModel {
    var messages: [ChatMessage] = []
    var state: ConversationState = .vazio
    var lastLatencyReport: LatencyReport?
    var errorMessage: String?
    var isListening: Bool = false
    var currentTranscript: String = ""
    var format: AnswerFormat {
        didSet {
            pipeline.format = format
        }
    }

    private let retriever: Retriever
    private let generator: AnswerGenerator
    private let formatter: ResponseFormatter
    private let lens: Lens
    private let transcriber: SpeechTranscriber
    private var detector: QuestionDetector
    private let clock: any Clock
    private var pipeline: AnswerPipeline

    init(
        retriever: Retriever,
        generator: AnswerGenerator,
        formatter: ResponseFormatter = LensFormatter(),
        lens: Lens,
        transcriber: SpeechTranscriber,
        detector: QuestionDetector = PauseQuestionDetector(),
        clock: any Clock = SystemClock(),
        format: AnswerFormat = .bullets
    ) {
        self.retriever = retriever
        self.generator = generator
        self.formatter = formatter
        self.lens = lens
        self.transcriber = transcriber
        self.detector = detector
        self.clock = clock
        self.format = format
        self.pipeline = AnswerPipeline(
            retriever: retriever,
            generator: generator,
            formatter: formatter,
            lens: lens,
            format: format,
            clock: clock
        )
    }

    /// Entrada por texto (US-12).
    func ask(_ text: String) async {
        await handleQuestion(text, sttDuration: nil)
    }

    /// Entrada por áudio streaming (US-01, US-02).
    func listen(_ audio: AsyncStream<AudioBuffer>) async {
        isListening = true
        state = .ouvindo
        detector.reset()

        var utteranceStart = clock.now()
        var lastTranscriptUpdateTime = utteranceStart
        var lastText = ""

        let transcripts = transcriber.transcribe(audio)
        for await transcript in transcripts {
            guard !Task.isCancelled else { break }
            currentTranscript = transcript.text
            let trimmed = transcript.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let now = clock.now()

            let silenceSeconds: Double
            if trimmed != lastText {
                lastText = trimmed
                lastTranscriptUpdateTime = now
                silenceSeconds = 0.0
            } else {
                silenceSeconds = lastTranscriptUpdateTime.duration(to: now).seconds
            }

            if let question = detector.feed(transcript, silenceSeconds: silenceSeconds) {
                let sttDuration = utteranceStart.duration(to: now)
                currentTranscript = ""
                await handleQuestion(question, sttDuration: sttDuration)
                detector.reset()
                lastText = ""
                utteranceStart = clock.now()
                lastTranscriptUpdateTime = utteranceStart
            }
        }

        isListening = false
        currentTranscript = ""
        if state == .ouvindo {
            state = messages.isEmpty ? .vazio : .respondido
        }
    }

    private func handleQuestion(_ question: String, sttDuration: Duration?) async {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state = .pensando
        errorMessage = nil

        do {
            let result = try await pipeline.ask(trimmed, sttDuration: sttDuration)
            lastLatencyReport = result.latency
            let message = ChatMessage(
                question: trimmed,
                answer: result.text,
                sources: result.sources,
                latency: result.latency
            )
            messages.append(message)
            if result.isNotFound {
                state = .semMaterial
            } else {
                state = .respondido
            }
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
