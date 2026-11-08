protocol Retriever: Sendable {
    func retrieve(_ question: String) async throws -> Retrieval
}
