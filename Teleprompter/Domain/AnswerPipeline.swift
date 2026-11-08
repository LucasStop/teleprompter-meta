import Foundation

/// Pergunta -> busca -> (nota | LLM com trechos | "não encontrei") -> formatador -> lente.
struct AnswerPipeline: Sendable {
    static let notFoundMessage = "Não encontrei isso no seu material."

    let retriever: Retriever
    let generator: AnswerGenerator
    let formatter: ResponseFormatter
    let lens: Lens
    var format: AnswerFormat = .bullets

    func ask(_ question: String) async throws {
        let found = try await retriever.retrieve(question)
        let text: String
        if let note = found.qaNote {
            text = note.text
        } else if found.isEmpty {
            text = Self.notFoundMessage
        } else {
            var acc = ""
            for await piece in generator.generate(question: question, context: found.chunks) { acc += piece }
            text = acc
        }
        let sources = ([found.qaNote] + found.chunks.map(Optional.some)).compactMap { $0?.source }
        await lens.show(LensContent(question: question, body: formatter.format(text, as: format), sources: sources))
    }
}
