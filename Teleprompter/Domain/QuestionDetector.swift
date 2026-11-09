/// Emite a pergunta completa uma única vez quando a pausa passa do limiar (US-02).
protocol QuestionDetector: Sendable {
    mutating func feed(_ transcript: Transcript, silenceSeconds: Double) -> String?
    mutating func reset()
}

extension QuestionDetector {
    mutating func reset() {}
}
