/// Emite a pergunta completa uma única vez quando a pausa passa do limiar (US-02). Implementação na fase 1 (P1).
protocol QuestionDetector: Sendable {
    func feed(_ transcript: Transcript, silenceSeconds: Double) -> String?
}
