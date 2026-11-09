import Foundation

/// Protocolo do executor de ensaios com fakes injetáveis para testes.
protocol EnsaioRunning: Sendable {
    func checkSpeechReadiness() async -> SpeechReadiness
    func run(
        items: [EnsaioItem],
        onProgress: (@Sendable (EnsaioRunProgress) -> Void)?
    ) async throws -> (summary: EnsaioRunSummary, results: [EnsaioQuestionResult])
    func cancel()
}

extension EnsaioRunning {
    func run(items: [EnsaioItem]) async throws -> (summary: EnsaioRunSummary, results: [EnsaioQuestionResult]) {
        try await run(items: items, onProgress: nil)
    }
}

/// Executor das perguntas do ensaio pelo pipeline (Áudio -> STT -> Busca -> LLM -> Lente).
final class EnsaioRunner: EnsaioRunning, @unchecked Sendable {
    typealias AudioSourceFactory = @Sendable (EnsaioItem) -> any AudioSource

    private let transcriber: any SpeechTranscriber
    private let retriever: any Retriever
    private let generator: any AnswerGenerator
    private let formatter: any ResponseFormatter
    private let lens: any Lens
    private let speechAssetManager: (any SpeechAssetManager)?
    private let audioSourceFactory: AudioSourceFactory
    private let clock: any Clock
    private let locale: Locale

    private let lock = NSLock()
    private var activeAudioSource: (any AudioSource)?
    private var isCancelled = false

    init(
        transcriber: any SpeechTranscriber,
        retriever: any Retriever,
        generator: any AnswerGenerator,
        formatter: any ResponseFormatter = LensFormatter(),
        lens: (any Lens)? = nil,
        speechAssetManager: (any SpeechAssetManager)? = nil,
        locale: Locale = Locale(identifier: "pt-BR"),
        clock: any Clock = SystemClock(),
        audioSourceFactory: AudioSourceFactory? = nil
    ) {
        self.transcriber = transcriber
        self.retriever = retriever
        self.generator = generator
        self.formatter = formatter
        self.lens = lens ?? SilentLens()
        self.speechAssetManager = speechAssetManager
        self.locale = locale
        self.clock = clock
        self.audioSourceFactory = audioSourceFactory ?? { item in
            if let url = item.audioURL {
                return FileAudioSource(url: url)
            }
            return EmptyAudioSource()
        }
    }

    func checkSpeechReadiness() async -> SpeechReadiness {
        guard let manager = speechAssetManager else { return .ready }
        let isSupported = await manager.isSupported(for: locale)
        guard isSupported else { return .unsupportedLocale(locale) }
        let isInstalled = await manager.isInstalled(for: locale)
        guard isInstalled else { return .assetNotInstalled(locale) }
        return .ready
    }

    func run(
        items: [EnsaioItem],
        onProgress: (@Sendable (EnsaioRunProgress) -> Void)? = nil
    ) async throws -> (summary: EnsaioRunSummary, results: [EnsaioQuestionResult]) {
        lock.withLock { isCancelled = false }
        if items.isEmpty {
            return (EnsaioRunSummary(results: []), [])
        }

        let pipeline = AnswerPipeline(
            retriever: retriever,
            generator: generator,
            formatter: formatter,
            lens: lens,
            format: .bullets,
            clock: clock
        )

        var results: [EnsaioQuestionResult] = []
        for (index, item) in items.enumerated() {
            if Task.isCancelled || isRunCancelled { break }
            reportProgress(index: index, itemsCount: items.count, title: item.title, onProgress: onProgress)

            guard let questionResult = try await processItem(item, pipeline: pipeline) else {
                break
            }
            results.append(questionResult)
        }

        if (Task.isCancelled || isRunCancelled) && results.isEmpty {
            throw CancellationError()
        }

        return (EnsaioRunSummary(results: results), results)
    }

    func cancel() {
        let sourceToStop = lock.withLock { () -> (any AudioSource)? in
            isCancelled = true
            let src = activeAudioSource
            activeAudioSource = nil
            return src
        }
        sourceToStop?.stop()
    }

    private var isRunCancelled: Bool {
        lock.withLock { isCancelled }
    }

    private func reportProgress(
        index: Int,
        itemsCount: Int,
        title: String,
        onProgress: (@Sendable (EnsaioRunProgress) -> Void)?
    ) {
        onProgress?(EnsaioRunProgress(
            currentIndex: index + 1,
            totalCount: itemsCount,
            currentQuestionTitle: title,
            fractionCompleted: Double(index + 1) / Double(itemsCount)
        ))
    }

    private func processItem(
        _ item: EnsaioItem,
        pipeline: AnswerPipeline
    ) async throws -> EnsaioQuestionResult? {
        let audioSource = audioSourceFactory(item)
        lock.withLock { activeAudioSource = audioSource }

        let sttStart = clock.now()
        guard let hypothesis = await transcribe(audioSource: audioSource) else {
            return nil
        }
        let sttDuration = sttStart.duration(to: clock.now())

        let wer = WordErrorRate.calculate(reference: item.referenceText, hypothesis: hypothesis)
        let query = hypothesis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? item.referenceText
            : hypothesis

        let pipelineResult = try await pipeline.ask(query, sttDuration: sttDuration)
        let kind = resolveSourceKind(from: pipelineResult)

        return EnsaioQuestionResult(
            id: item.id,
            referenceQuestion: item.referenceText,
            transcribedText: hypothesis,
            wer: wer,
            answer: pipelineResult.text,
            answerKind: kind,
            latency: pipelineResult.latency
        )
    }

    private func transcribe(audioSource: any AudioSource) async -> String? {
        let audioStream = audioSource.start()
        let transcriptStream = transcriber.transcribe(audioStream)

        var hypothesis = ""
        for await transcript in transcriptStream {
            if Task.isCancelled || isRunCancelled {
                audioSource.stop()
                break
            }
            hypothesis = transcript.text
            if transcript.isFinal { break }
        }

        audioSource.stop()
        lock.withLock { activeAudioSource = nil }

        if Task.isCancelled || isRunCancelled {
            return nil
        }
        return hypothesis
    }

    private func resolveSourceKind(from result: AnswerPipeline.Result) -> AnswerSourceKind {
        if result.isNotFound {
            return .notFound
        } else if result.latency.firstToken == nil {
            return .qaNote
        } else {
            return .llm
        }
    }
}

/// Lente silenciosa padrão para o executor de ensaios.
private struct SilentLens: Lens {
    func show(_ content: LensContent) async {}
    func clear() async {}
}

/// Fonte de áudio silenciosa para testes ou itens sem URL.
private struct EmptyAudioSource: AudioSource {
    func start() -> AsyncStream<AudioBuffer> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    func stop() {}
}
