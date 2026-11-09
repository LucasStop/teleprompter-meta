import SwiftUI

private struct MockIndexable: MaterialIndexable {
    func index(_ items: [IndexedChunk]) throws {}
    func removeSource(_ path: String) throws {}
}

private struct MockFolderScanner: FolderScanning {
    var shouldFail: Bool = false

    func scan(url: URL) throws -> FolderScanResult {
        if shouldFail {
            throw FolderScannerError.unreadableFolder(
                name: url.lastPathComponent,
                reason: "Sem permissão de leitura. Escolha a pasta de novo."
            )
        }

        var valid: [ScannedFile] = []
        for index in 1...22 {
            let path = "qa/p\(index).md"
            valid.append(ScannedFile(relativePath: path, url: url.appendingPathComponent(path), kind: .qa, size: 500))
        }
        for index in 1...31 {
            let path = "docs/doc\(index).md"
            valid.append(ScannedFile(relativePath: path, url: url.appendingPathComponent(path), kind: .document, size: 1000))
        }
        for index in 1...90 {
            let path = "src/file\(index).swift"
            valid.append(ScannedFile(relativePath: path, url: url.appendingPathComponent(path), kind: .code, size: 2000))
        }

        var ignored: [IgnoredFile] = []
        for index in 1...1204 {
            ignored.append(IgnoredFile(relativePath: ".git/obj\(index)", reason: .ignoredDirectory))
        }
        for index in 1...3 {
            ignored.append(IgnoredFile(relativePath: "large\(index).bin", reason: .tooLarge))
        }
        for index in 1...58 {
            ignored.append(IgnoredFile(relativePath: "assets/img\(index).png", reason: .binary))
        }

        return FolderScanResult(
            folderName: url.lastPathComponent,
            folderURL: url,
            validFiles: valid,
            ignoredFiles: ignored
        )
    }
}

private struct MockFileSource: MaterialFileSource {
    func read(from url: URL) throws -> MaterialFileContent {
        MaterialFileContent(name: url.lastPathComponent, text: "Conteúdo de exemplo")
    }
}

@MainActor
private enum MaterialPreviewHelper {
    static let sampleSources = [
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

    static func make(kind: MaterialScreenState.Kind) -> MaterialViewModel {
        switch kind {
        case .vazio, .padrao, .carregando, .erro:
            return makeStandardPreview(kind: kind)
        case .pastaConfirmar, .pastaIndexando, .pastaConcluido, .pastaErro:
            return makeFolderPreview(kind: kind)
        }
    }

    private static func makeStandardPreview(kind: MaterialScreenState.Kind) -> MaterialViewModel {
        let indexable = MockIndexable()
        switch kind {
        case .vazio:
            return MaterialViewModel(indexable: indexable, initialSources: [])
        case .padrao:
            return MaterialViewModel(indexable: indexable, initialSources: sampleSources)
        case .carregando:
            let model = MaterialViewModel(indexable: indexable, initialSources: sampleSources)
            Task { await model.importContent(name: "teleprompter-meta", content: "placeholder") }
            return model
        case .erro:
            let model = MaterialViewModel(indexable: indexable, initialSources: [sampleSources[1]])
            Task { await model.importContent(name: "docs/PRD.md", content: "") }
            return model
        default:
            return MaterialViewModel(indexable: indexable)
        }
    }

    private static func makeFolderPreview(kind: MaterialScreenState.Kind) -> MaterialViewModel {
        let indexable = MockIndexable()
        switch kind {
        case .pastaConfirmar:
            let model = MaterialViewModel(indexable: indexable, scanner: MockFolderScanner())
            Task { await model.selectFolder(url: URL(fileURLWithPath: "/workspace/teleprompter-meta")) }
            return model
        case .pastaIndexando:
            let model = MaterialViewModel(indexable: indexable, fileSource: MockFileSource(), scanner: MockFolderScanner())
            Task {
                await model.selectFolder(url: URL(fileURLWithPath: "/workspace/teleprompter-meta"))
                _ = Task { await model.confirmFolderImport() }
            }
            return model
        case .pastaConcluido:
            let folderSources = [
                MaterialSource(name: "Notas de Q&A", path: "folder:qa", kind: .qa, chunkCount: 22, subtitle: "22 arquivos"),
                MaterialSource(name: "Documentos", path: "folder:docs", kind: .document, chunkCount: 184, subtitle: "31 arquivos"),
                MaterialSource(name: "Código", path: "folder:code", kind: .code, chunkCount: 1059, subtitle: "90 arquivos")
            ]
            let model = MaterialViewModel(
                indexable: indexable,
                fileSource: MockFileSource(),
                scanner: MockFolderScanner(),
                initialSources: folderSources
            )
            Task {
                await model.selectFolder(url: URL(fileURLWithPath: "/workspace/teleprompter-meta"))
                await model.confirmFolderImport()
            }
            return model
        case .pastaErro:
            let model = MaterialViewModel(
                indexable: indexable,
                scanner: MockFolderScanner(shouldFail: true),
                initialSources: [sampleSources[1]]
            )
            Task { await model.selectFolder(url: URL(fileURLWithPath: "/workspace/teleprompter-meta")) }
            return model
        default:
            return MaterialViewModel(indexable: indexable)
        }
    }
}

// MARK: - Previews para os 8 Estados nos Dois Temas (DESIGN.md / design/prototypes/t04-importacao.html)

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

#Preview("T04 - 5. Pasta: confirmar (Claro)") {
    MaterialView(viewModel: MaterialPreviewHelper.make(kind: .pastaConfirmar))
}

#Preview("T04 - 5. Pasta: confirmar (Escuro)") {
    MaterialView(viewModel: MaterialPreviewHelper.make(kind: .pastaConfirmar))
        .preferredColorScheme(.dark)
}

#Preview("T04 - 6. Pasta: indexando (Claro)") {
    MaterialView(viewModel: MaterialPreviewHelper.make(kind: .pastaIndexando))
}

#Preview("T04 - 6. Pasta: indexando (Escuro)") {
    MaterialView(viewModel: MaterialPreviewHelper.make(kind: .pastaIndexando))
        .preferredColorScheme(.dark)
}

#Preview("T04 - 7. Pasta: concluído (Claro)") {
    MaterialView(viewModel: MaterialPreviewHelper.make(kind: .pastaConcluido))
}

#Preview("T04 - 7. Pasta: concluído (Escuro)") {
    MaterialView(viewModel: MaterialPreviewHelper.make(kind: .pastaConcluido))
        .preferredColorScheme(.dark)
}

#Preview("T04 - 8. Pasta: erro (Claro)") {
    MaterialView(viewModel: MaterialPreviewHelper.make(kind: .pastaErro))
}

#Preview("T04 - 8. Pasta: erro (Escuro)") {
    MaterialView(viewModel: MaterialPreviewHelper.make(kind: .pastaErro))
        .preferredColorScheme(.dark)
}
