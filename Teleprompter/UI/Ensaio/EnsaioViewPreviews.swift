import SwiftUI

#Preview("Ensaio - Vazio (Claro)") {
    let viewModel = EnsaioViewModel(runner: PreviewEnsaioRunner(), itemSource: PreviewEnsaioItemSource(items: []))
    viewModel.screenState = .vazio
    return EnsaioView(viewModel: viewModel)
}

#Preview("Ensaio - Vazio (Escuro)") {
    let viewModel = EnsaioViewModel(runner: PreviewEnsaioRunner(), itemSource: PreviewEnsaioItemSource(items: []))
    viewModel.screenState = .vazio
    return EnsaioView(viewModel: viewModel)
        .preferredColorScheme(.dark)
}

#Preview("Ensaio - Rodando (Claro)") {
    let viewModel = EnsaioViewModel(runner: PreviewEnsaioRunner(), itemSource: PreviewEnsaioItemSource(items: []))
    viewModel.screenState = .rodando(
        current: 12,
        total: 30,
        questionTitle: "Como a busca funciona?"
    )
    return EnsaioView(viewModel: viewModel)
}

#Preview("Ensaio - Rodando (Escuro)") {
    let viewModel = EnsaioViewModel(runner: PreviewEnsaioRunner(), itemSource: PreviewEnsaioItemSource(items: []))
    viewModel.screenState = .rodando(
        current: 12,
        total: 30,
        questionTitle: "Como a busca funciona?"
    )
    return EnsaioView(viewModel: viewModel)
        .preferredColorScheme(.dark)
}

#Preview("Ensaio - Padrão (Claro)") {
    let viewModel = EnsaioViewModel(runner: PreviewEnsaioRunner(), itemSource: PreviewEnsaioItemSource(items: []))
    let questions = previewQuestions()
    let summary = EnsaioRunSummary(results: questions)
    viewModel.screenState = .padrao(summary: summary, questions: questions)
    return EnsaioView(viewModel: viewModel)
}

#Preview("Ensaio - Padrão (Escuro)") {
    let viewModel = EnsaioViewModel(runner: PreviewEnsaioRunner(), itemSource: PreviewEnsaioItemSource(items: []))
    let questions = previewQuestions()
    let summary = EnsaioRunSummary(results: questions)
    viewModel.screenState = .padrao(summary: summary, questions: questions)
    return EnsaioView(viewModel: viewModel)
        .preferredColorScheme(.dark)
}

#Preview("Ensaio - Erro (Claro)") {
    let viewModel = EnsaioViewModel(runner: PreviewEnsaioRunner(), itemSource: PreviewEnsaioItemSource(items: []))
    viewModel.screenState = .erro(
        title: "Modelo de fala não instalado",
        message: "O modelo de reconhecimento de fala em português (pt-BR) precisa ser instalado antes de iniciar o ensaio.",
        actionTitle: "Instalar modelo"
    )
    return EnsaioView(viewModel: viewModel)
}

#Preview("Ensaio - Erro (Escuro)") {
    let viewModel = EnsaioViewModel(runner: PreviewEnsaioRunner(), itemSource: PreviewEnsaioItemSource(items: []))
    viewModel.screenState = .erro(
        title: "Modelo de fala não instalado",
        message: "O modelo de reconhecimento de fala em português (pt-BR) precisa ser instalado antes de iniciar o ensaio.",
        actionTitle: "Instalar modelo"
    )
    return EnsaioView(viewModel: viewModel)
        .preferredColorScheme(.dark)
}

// MARK: - Previews Helpers

private func previewQuestions() -> [EnsaioQuestionResult] {
    let item1 = EnsaioQuestionResult(
        id: "1",
        referenceQuestion: "Por que Swift nativo?",
        transcribedText: "por que swift nativo",
        wer: 0.04,
        answer: "• DAT SDK só tem módulos Swift\n• Menor latência de áudio\n• Acesso direto ao SpeechAnalyzer",
        answerKind: .qaNote,
        latency: LatencyReport(retrievalSeconds: 0.05, firstTokenSeconds: nil, totalSeconds: 0.6),
        isOk: true
    )
    let item2 = EnsaioQuestionResult(
        id: "2",
        referenceQuestion: "Como a busca funciona?",
        transcribedText: "como a busca funciona",
        wer: 0.09,
        answer: "Busca híbrida com BM25 e embeddings locais no SQLite FTS5.",
        answerKind: .llm,
        latency: LatencyReport(retrievalSeconds: 0.12, firstTokenSeconds: 1.3, totalSeconds: 1.3),
        isOk: true
    )
    let item3 = EnsaioQuestionResult(
        id: "3",
        referenceQuestion: "Qual o orçamento?",
        transcribedText: "qual o orçamento",
        wer: 0.12,
        answer: "Não encontrei isso no seu material.",
        answerKind: .notFound,
        latency: LatencyReport(retrievalSeconds: 0.08, firstTokenSeconds: nil, totalSeconds: 0.08),
        isOk: true
    )
    let item4 = EnsaioQuestionResult(
        id: "4",
        referenceQuestion: "E se a rede cair?",
        transcribedText: "e se a rede cair",
        wer: 0.14,
        answer: "O app opera offline para notas de Q&A e busca em documentos indexados localmente.",
        answerKind: .llm,
        latency: LatencyReport(retrievalSeconds: 0.15, firstTokenSeconds: 2.4, totalSeconds: 2.4),
        isOk: false
    )
    return [item1, item2, item3, item4]
}

private final class PreviewEnsaioRunner: EnsaioRunning, @unchecked Sendable {
    func checkSpeechReadiness() async -> SpeechReadiness { .ready }
    func run(
        items: [EnsaioItem],
        onProgress: (@Sendable (EnsaioRunProgress) -> Void)?
    ) async throws -> (summary: EnsaioRunSummary, results: [EnsaioQuestionResult]) {
        (EnsaioRunSummary(results: []), [])
    }
    func cancel() {}
}

private struct PreviewEnsaioItemSource: EnsaioItemSource {
    let items: [EnsaioItem]
    func loadItems() async throws -> [EnsaioItem] { items }
}
