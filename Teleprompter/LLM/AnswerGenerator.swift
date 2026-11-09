protocol AnswerGenerator: Sendable {
    func generate(question: String, context: [Chunk]) -> AsyncStream<String>
}
