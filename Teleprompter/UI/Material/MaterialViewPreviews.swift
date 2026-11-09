import SwiftUI

private struct MockIndexable: MaterialIndexable {
    func index(_ items: [IndexedChunk]) throws {}
    func removeSource(_ path: String) throws {}
}

@MainActor
private enum MaterialPreviewHelper {
    static func make(kind: MaterialScreenState.Kind) -> MaterialViewModel {
        let indexable = MockIndexable()
        let sampleSources = [
            MaterialSource(
                name: "Notas de Q&A",
                path: "qa/apresentacao.md",
                kind: .qa,
                chunkCount: 30,
                subtitle: "30 perguntas"
            ),
            MaterialSource(
                name: "README.md",
                path: "README.md",
                kind: .document,
                chunkCount: 12,
                subtitle: "Importado hoje"
            ),
            MaterialSource(
                name: "Documentos",
                path: "docs/PRD.md",
                kind: .document,
                chunkCount: 148,
                subtitle: "PRD, ADRs, plano"
            ),
            MaterialSource(
                name: "Repositório",
                path: "Teleprompter/",
                kind: .code,
                chunkCount: 812,
                subtitle: "teleprompter-meta @ 9ac027f"
            )
        ]

        switch kind {
        case .vazio:
            return MaterialViewModel(indexable: indexable, initialSources: [])
        case .padrao:
            return MaterialViewModel(indexable: indexable, initialSources: sampleSources)
        case .carregando:
            let model = MaterialViewModel(indexable: indexable, initialSources: sampleSources)
            Task {
                await model.importContent(name: "teleprompter-meta", content: "placeholder")
            }
            return model
        case .erro:
            let model = MaterialViewModel(indexable: indexable, initialSources: [sampleSources[1]])
            Task {
                await model.importContent(name: "docs/PRD.md", content: "")
            }
            return model
        }
    }
}

// MARK: - Previews para os 4 Estados nos Dois Temas (DESIGN.md 1.8 / design/prototypes/t04-importacao.html)

#Preview("T04 - 1. Vazio (Claro)") {
    MaterialView(viewModel: MaterialPreviewHelper.make(kind: .vazio))
}

#Preview("T04 - 1. Vazio (Escuro)") {
    MaterialView(viewModel: MaterialPreviewHelper.make(kind: .vazio))
        .preferredColorScheme(.dark)
}

#Preview("T04 - 2. Padrão (Claro)") {
    MaterialView(viewModel: MaterialPreviewHelper.make(kind: .padrao))
}

#Preview("T04 - 2. Padrão (Escuro)") {
    MaterialView(viewModel: MaterialPreviewHelper.make(kind: .padrao))
        .preferredColorScheme(.dark)
}

#Preview("T04 - 3. Carregando (Claro)") {
    MaterialView(viewModel: MaterialPreviewHelper.make(kind: .carregando))
}

#Preview("T04 - 3. Carregando (Escuro)") {
    MaterialView(viewModel: MaterialPreviewHelper.make(kind: .carregando))
        .preferredColorScheme(.dark)
}

#Preview("T04 - 4. Erro (Claro)") {
    MaterialView(viewModel: MaterialPreviewHelper.make(kind: .erro))
}

#Preview("T04 - 4. Erro (Escuro)") {
    MaterialView(viewModel: MaterialPreviewHelper.make(kind: .erro))
        .preferredColorScheme(.dark)
}
