import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

struct FoundationModelsAnswerGenerator: AnswerGenerator {
    static let defaultSystemPrompt = """
    Você é o assistente do Teleprompter. Responda exclusivamente com base nos trechos fornecidos no contexto.
    Responda de forma curta e em tópicos.
    Se os trechos não forem suficientes para responder, diga exatamente: "Não encontrei isso no seu material."
    """

    let systemPrompt: String

    init(systemPrompt: String = Self.defaultSystemPrompt) {
        self.systemPrompt = systemPrompt
    }

    static var isSupported: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            return SystemLanguageModel.default.availability == .available
        }
        #endif
        return false
    }

    func generate(question: String, context: [Chunk]) -> AsyncStream<String> {
        guard !context.isEmpty else {
            return AsyncStream { $0.finish() }
        }

        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            return AsyncStream { continuation in
                let task = Task {
                    do {
                        let model = SystemLanguageModel.default
                        guard case .available = model.availability else {
                            continuation.finish()
                            return
                        }
                        let session = LanguageModelSession(instructions: systemPrompt)
                        let contextBody = context.map { chunk in
                            "Fonte: \(chunk.source.path)\n\(chunk.text)"
                        }.joined(separator: "\n\n")
                        let userPrompt = "Contexto:\n\(contextBody)\n\nPergunta:\n\(question)"
                        let stream = session.streamResponse(to: Prompt(userPrompt))
                        var previousLength = 0
                        for try await snapshot in stream {
                            try Task.checkCancellation()
                            let content = snapshot.content
                            if content.count > previousLength {
                                let startIndex = content.index(content.startIndex, offsetBy: previousLength)
                                let delta = String(content[startIndex...])
                                previousLength = content.count
                                continuation.yield(delta)
                            }
                        }
                    } catch {
                        // Cancelamento ou falha do modelo on-device
                    }
                    continuation.finish()
                }

                continuation.onTermination = { @Sendable _ in
                    task.cancel()
                }
            }
        }
        #endif

        return AsyncStream { $0.finish() }
    }
}
