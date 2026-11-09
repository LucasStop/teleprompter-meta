import Foundation

struct StreamingAnswerGenerator: AnswerGenerator {
    enum Format: String, Sendable, Equatable, CaseIterable {
        case openAI
        case anthropic
    }

    static let defaultSystemPrompt = """
    Você é o assistente do Teleprompter. Responda exclusivamente com base nos trechos fornecidos no contexto;
    nunca use conhecimento externo nem invente.
    Responda de forma curta e em tópicos.
    Ao fim de cada tópico, indique a citação [n] usando apenas os números do contexto.
    Se os trechos trazem informação que responde à pergunta, mesmo que parcialmente, responda com o que eles dizem e indique o que faltou.
    Só se nenhum trecho tiver relação com a pergunta, responda exatamente: "Não encontrei isso no seu material."
    """

    let baseURL: URL
    let model: String
    let secretStore: SecretStore
    let apiKeyKey: String
    let format: Format
    let maxTokens: Int
    let timeout: TimeInterval
    let session: URLSession
    let systemPrompt: String
    let onError: (@Sendable (LLMError) -> Void)?

    init(
        baseURL: URL,
        model: String,
        secretStore: SecretStore,
        apiKeyKey: String = "llm_api_key",
        format: Format = .openAI,
        maxTokens: Int = 1024,
        timeout: TimeInterval = 30,
        session: URLSession = .shared,
        systemPrompt: String = Self.defaultSystemPrompt,
        onError: (@Sendable (LLMError) -> Void)? = nil
    ) {
        self.baseURL = baseURL
        self.model = model
        self.secretStore = secretStore
        self.apiKeyKey = apiKeyKey
        self.format = format
        self.maxTokens = maxTokens
        self.timeout = timeout
        self.session = session
        self.systemPrompt = systemPrompt
        self.onError = onError
    }

    func generate(question: String, context: [Chunk]) -> AsyncStream<String> {
        guard !context.isEmpty else {
            return AsyncStream { $0.finish() }
        }

        return AsyncStream { continuation in
            let task = Task {
                do {
                    try await streamDeltas(
                        to: { delta in continuation.yield(delta) },
                        question: question,
                        context: context
                    )
                } catch let error as LLMError {
                    onError?(error)
                } catch is CancellationError {
                    // Cancelamento limpo da task
                } catch {
                    onError?(.network(error.localizedDescription))
                }
                continuation.finish()
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    func generateThrowing(question: String, context: [Chunk]) -> AsyncThrowingStream<String, Error> {
        guard !context.isEmpty else {
            return AsyncThrowingStream { $0.finish() }
        }

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await streamDeltas(
                        to: { delta in continuation.yield(delta) },
                        question: question,
                        context: context
                    )
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}

// MARK: - Pipeline de Requisição e Eventos

extension StreamingAnswerGenerator {
    private var endpointURL: URL {
        switch format {
        case .openAI:
            if baseURL.lastPathComponent == "completions" {
                return baseURL
            }
            return baseURL.appendingPathComponent("chat/completions")
        case .anthropic:
            if baseURL.lastPathComponent == "messages" {
                return baseURL
            }
            return baseURL.appendingPathComponent("messages")
        }
    }

    private func streamDeltas(
        to yield: @Sendable (String) -> Void,
        question: String,
        context: [Chunk]
    ) async throws {
        let apiKey = try fetchAPIKey()
        let request = try makeRequest(question: question, context: context, apiKey: apiKey)
        let (asyncBytes, httpResponse) = try await send(request: request, apiKey: apiKey)

        guard (200...299).contains(httpResponse.statusCode) else {
            throw LLMError.httpStatus(httpResponse.statusCode)
        }

        try await processEvents(from: asyncBytes, to: yield, apiKey: apiKey)
    }

    private func send(request: URLRequest, apiKey: String) async throws -> (URLSession.AsyncBytes, HTTPURLResponse) {
        let asyncBytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (asyncBytes, response) = try await session.bytes(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let urlError as URLError where urlError.code == .cancelled {
            throw CancellationError()
        } catch {
            throw LLMError.network(sanitize(error.localizedDescription, apiKey: apiKey))
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }
        return (asyncBytes, httpResponse)
    }

    private func processEvents(
        from asyncBytes: URLSession.AsyncBytes,
        to yield: @Sendable (String) -> Void,
        apiKey: String
    ) async throws {
        do {
            for try await rawLine in asyncBytes.lines {
                try Task.checkCancellation()
                if let delta = try parseSSELine(rawLine) {
                    if delta.isDone { break }
                    if let text = delta.text { yield(text) }
                }
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch let urlError as URLError where urlError.code == .cancelled {
            throw CancellationError()
        } catch let error as LLMError {
            throw error
        } catch {
            throw LLMError.network(sanitize(error.localizedDescription, apiKey: apiKey))
        }
    }

    private func fetchAPIKey() throws -> String {
        let key: String?
        do {
            key = try secretStore.get(key: apiKeyKey)
        } catch {
            throw LLMError.missingAPIKey
        }
        guard let key = key?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty else {
            throw LLMError.missingAPIKey
        }
        return key
    }

    private func sanitize(_ text: String, apiKey: String) -> String {
        guard !apiKey.isEmpty else { return text }
        return text.replacingOccurrences(of: apiKey, with: "[REDACTED]")
    }
}

// MARK: - Construção de Requisições

extension StreamingAnswerGenerator {
    static func formatContextBody(context: [Chunk]) -> String {
        var uniquePaths: [String] = []
        var pathToIndex: [String: Int] = [:]
        for chunk in context {
            let path = chunk.source.path
            if pathToIndex[path] == nil {
                uniquePaths.append(path)
                pathToIndex[path] = uniquePaths.count
            }
        }

        return context.map { chunk in
            let number = pathToIndex[chunk.source.path] ?? 1
            return "[\(number)] Fonte: \(chunk.source.path)\n\(chunk.text)"
        }.joined(separator: "\n\n")
    }

    func makeRequest(question: String, context: [Chunk], apiKey: String) throws -> URLRequest {
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        let contextBody = Self.formatContextBody(context: context)

        let userPrompt = "Contexto:\n\(contextBody)\n\nPergunta:\n\(question)"
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes

        switch format {
        case .openAI:
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            let body = ChatCompletionRequestBody(
                model: model,
                messages: [
                    ChatCompletionMessage(role: "system", content: systemPrompt),
                    ChatCompletionMessage(role: "user", content: userPrompt)
                ],
                stream: true
            )
            request.httpBody = try encoder.encode(body)

        case .anthropic:
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            let body = AnthropicRequestBody(
                model: model,
                maxTokens: maxTokens,
                system: systemPrompt,
                messages: [
                    AnthropicMessage(role: "user", content: userPrompt)
                ],
                stream: true
            )
            request.httpBody = try encoder.encode(body)
        }

        return request
    }
}

// MARK: - Parsing de SSE

extension StreamingAnswerGenerator {
    private struct ParsedDelta {
        let text: String?
        let isDone: Bool
    }

    private func parseSSELine(_ rawLine: String) throws -> ParsedDelta? {
        let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if line.isEmpty || line.hasPrefix(":") || !line.hasPrefix("data:") {
            return nil
        }
        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)

        switch format {
        case .openAI:
            return try parseOpenAIPayload(payload)
        case .anthropic:
            return try parseAnthropicPayload(payload)
        }
    }

    private func parseOpenAIPayload(_ payload: String) throws -> ParsedDelta? {
        if payload == "[DONE]" {
            return ParsedDelta(text: nil, isDone: true)
        }
        guard let data = payload.data(using: .utf8),
              let chunk = try? JSONDecoder().decode(ChatCompletionChunk.self, from: data) else {
            throw LLMError.invalidResponse
        }
        let piece = chunk.choices?.compactMap(\.delta?.content).first(where: { !$0.isEmpty })
        return ParsedDelta(text: piece, isDone: false)
    }

    private func parseAnthropicPayload(_ payload: String) throws -> ParsedDelta? {
        guard let data = payload.data(using: .utf8),
              let chunk = try? JSONDecoder().decode(AnthropicChunk.self, from: data) else {
            throw LLMError.invalidResponse
        }
        switch chunk.type {
        case "content_block_delta":
            let piece = chunk.delta?.text
            return ParsedDelta(text: (piece?.isEmpty ?? true) ? nil : piece, isDone: false)
        case "message_stop":
            return ParsedDelta(text: nil, isDone: true)
        case "error":
            throw LLMError.network(chunk.error?.message ?? "Erro na resposta do Anthropic")
        default:
            return ParsedDelta(text: nil, isDone: false)
        }
    }
}

// MARK: - Modelos de Requisição e Resposta OpenAI

private struct ChatCompletionMessage: Encodable {
    let role: String
    let content: String
}

private struct ChatCompletionRequestBody: Encodable {
    let model: String
    let messages: [ChatCompletionMessage]
    let stream: Bool
}

private struct ChatCompletionDelta: Decodable {
    let content: String?
}

private struct ChatCompletionChoice: Decodable {
    let delta: ChatCompletionDelta?
}

private struct ChatCompletionChunk: Decodable {
    let choices: [ChatCompletionChoice]?
}

// MARK: - Modelos de Requisição e Resposta Anthropic

private struct AnthropicRequestBody: Encodable {
    let model: String
    let maxTokens: Int
    let system: String
    let messages: [AnthropicMessage]
    let stream: Bool

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case system
        case messages
        case stream
    }
}

private struct AnthropicMessage: Encodable {
    let role: String
    let content: String
}

private struct AnthropicChunk: Decodable {
    let type: String
    let delta: AnthropicDelta?
    let error: AnthropicErrorPayload?
}

private struct AnthropicDelta: Decodable {
    let type: String?
    let text: String?
}

private struct AnthropicErrorPayload: Decodable {
    let type: String?
    let message: String?
}
