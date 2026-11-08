protocol ResponseFormatter: Sendable {
    func format(_ text: String, as format: AnswerFormat) -> String
}
