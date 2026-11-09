import Foundation

/// Pergunta -> busca -> (nota | LLM com trechos | "não encontrei") -> formatador -> lente.
struct AnswerPipeline: Sendable {
    static let notFoundMessage = "Não encontrei isso no seu material."

    let retriever: Retriever
    let generator: AnswerGenerator
    let formatter: ResponseFormatter
    let lens: Lens
    var format: AnswerFormat = .bullets
    var clock: any Clock = SystemClock()

    struct Result: Sendable, Equatable {
        var text: String
        var formattedBody: String
        var sources: [SourceRef]
        var isNotFound: Bool
        var latency: LatencyReport
    }

    @discardableResult
    func ask(_ question: String, sttDuration: Duration? = nil) async throws -> Result {
        let start = clock.now()
        let retrievalStart = clock.now()
        let found = try await retriever.retrieve(question)
        let retrievalDuration = retrievalStart.duration(to: clock.now())

        let text: String
        var firstTokenDuration: Duration?
        let isNotFound: Bool

        if let note = found.qaNote {
            text = note.text
            isNotFound = false
        } else if found.isEmpty {
            text = Self.notFoundMessage
            isNotFound = true
        } else {
            isNotFound = false
            let llmStart = clock.now()
            var acc = ""
            for await piece in generator.generate(question: question, context: found.chunks) {
                if acc.isEmpty && !piece.isEmpty {
                    firstTokenDuration = llmStart.duration(to: clock.now())
                }
                acc += piece
            }
            if acc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw LLMError.invalidResponse
            }
            text = acc
        }

        let sources = deduplicateSources(from: found)
        let textForLens = CitationParser.stripCitations(text)
        let formattedBody = formatter.format(textForLens, as: format)
        await lens.show(LensContent(question: question, body: formattedBody, sources: sources))
        let totalDuration = start.duration(to: clock.now())

        let latency = LatencyReport(
            sttFinal: sttDuration,
            retrieval: retrievalDuration,
            firstToken: firstTokenDuration,
            total: totalDuration
        )

        return Result(
            text: text,
            formattedBody: formattedBody,
            sources: sources,
            isNotFound: isNotFound,
            latency: latency
        )
    }

    private func deduplicateSources(from found: Retrieval) -> [SourceRef] {
        let rawSources = ([found.qaNote] + found.chunks.map(Optional.some)).compactMap { $0?.source }
        var uniqueSources: [SourceRef] = []
        var seenPaths: Set<String> = []
        for ref in rawSources where !seenPaths.contains(ref.path) {
            seenPaths.insert(ref.path)
            uniqueSources.append(ref)
        }
        return uniqueSources
    }
}
