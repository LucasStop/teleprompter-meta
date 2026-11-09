import Foundation
import Observation

/// ViewModel para a aba de Material (T04).
/// Controla o fluxo de importação, estados de tela e comunicação com o índice de busca.
@MainActor
@Observable
final class MaterialViewModel {
    private(set) var sources: [MaterialSource] = []
    private(set) var lastUpdated: Date?
    private(set) var loadingState: MaterialScreenState.LoadingState?
    private(set) var errorMessage: (title: String, message: String)?

    var isPickingFile: Bool = false
    var isShowingClearConfirmation: Bool = false

    private let indexable: any MaterialIndexable
    private let importer: MaterialImporter
    private let fileSource: any MaterialFileSource

    private var lastAttempt: (@Sendable () async -> Void)?

    init(
        indexable: any MaterialIndexable,
        importer: MaterialImporter = MaterialImporter(),
        fileSource: any MaterialFileSource = DefaultMaterialFileSource(),
        initialSources: [MaterialSource] = []
    ) {
        self.indexable = indexable
        self.importer = importer
        self.fileSource = fileSource
        self.sources = initialSources
        if !initialSources.isEmpty {
            self.lastUpdated = Date()
        }
    }

    var screenState: MaterialScreenState {
        if let loading = loadingState {
            return MaterialScreenState(
                kind: .carregando,
                badge: MaterialScreenState.BadgeState(
                    status: .ativo,
                    title: "Indexando \(loading.sourceName)"
                ),
                sources: sources,
                loading: loading
            )
        }

        if let error = errorMessage {
            return MaterialScreenState(
                kind: .erro,
                banner: MaterialScreenState.BannerState(
                    style: .danger,
                    title: error.title,
                    message: error.message,
                    actionTitle: "Tentar de novo"
                ),
                sources: sources
            )
        }

        if sources.isEmpty {
            return MaterialScreenState(kind: .vazio)
        }

        return MaterialScreenState(
            kind: .padrao,
            badge: MaterialScreenState.BadgeState(
                status: .ok,
                title: formattedLastUpdated
            ),
            sources: sources
        )
    }

    private var formattedLastUpdated: String {
        guard let lastUpdated else {
            return "Índice atualizado agora"
        }
        let elapsed = Date().timeIntervalSince(lastUpdated)
        if elapsed < 60 {
            return "Índice atualizado agora"
        }
        let minutes = Int(elapsed / 60)
        if minutes < 60 {
            return "Índice atualizado há \(minutes) min"
        }
        let hours = Int(minutes / 60)
        return "Índice atualizado há \(hours) h"
    }

    // MARK: - Ações de Importação

    func importFile(from url: URL) async {
        lastAttempt = { [weak self] in
            await self?.importFile(from: url)
        }
        errorMessage = nil

        let fileName = url.lastPathComponent
        loadingState = MaterialScreenState.LoadingState(
            sourceName: fileName,
            current: 0,
            total: 1,
            progress: 0.1
        )

        do {
            let fileContent = try fileSource.read(from: url)
            await processContent(name: fileContent.name, content: fileContent.text)
        } catch let error as MaterialImporterError {
            setImportError(for: fileName, error: error)
        } catch {
            errorMessage = (
                title: "Não consegui ler \"\(fileName)\".",
                message: error.localizedDescription
            )
            loadingState = nil
        }
    }

    func importContent(name: String, content: String) async {
        lastAttempt = { [weak self] in
            await self?.importContent(name: name, content: content)
        }
        errorMessage = nil

        loadingState = MaterialScreenState.LoadingState(
            sourceName: name,
            current: 0,
            total: 1,
            progress: 0.1
        )

        await processContent(name: name, content: content)
    }

    private func processContent(name: String, content: String) async {
        do {
            let chunks = try importer.parse(content: content, sourceName: name)
            guard !chunks.isEmpty else {
                throw MaterialImporterError.emptyFile(name)
            }

            loadingState = MaterialScreenState.LoadingState(
                sourceName: name,
                current: chunks.count / 2,
                total: chunks.count,
                progress: 0.5
            )

            // Substitui trechos antigos da mesma fonte (reimportação sem duplicação)
            try indexable.removeSource(name)
            try indexable.index(chunks)

            loadingState = MaterialScreenState.LoadingState(
                sourceName: name,
                current: chunks.count,
                total: chunks.count,
                progress: 1.0
            )

            let kind = chunks.first?.kind ?? .document
            let subtitle = makeSubtitle(kind: kind, count: chunks.count)
            let newSource = MaterialSource(
                name: name,
                path: name,
                kind: kind,
                chunkCount: chunks.count,
                subtitle: subtitle,
                importedAt: Date()
            )

            if let existingIndex = sources.firstIndex(where: { $0.path == name }) {
                sources[existingIndex] = newSource
            } else {
                sources.append(newSource)
            }

            lastUpdated = Date()
            errorMessage = nil
            loadingState = nil
        } catch let error as MaterialImporterError {
            setImportError(for: name, error: error)
        } catch {
            errorMessage = (
                title: "Não consegui ler \"\(name)\".",
                message: error.localizedDescription
            )
            loadingState = nil
        }
    }

    private func setImportError(for name: String, error: MaterialImporterError) {
        switch error {
        case .emptyFile(let fileName):
            errorMessage = (
                title: "Não consegui indexar \"\(fileName)\".",
                message: error.localizedDescription
            )
        case .unreadableFile(let fileName, _):
            errorMessage = (
                title: "Não consegui ler \"\(fileName)\".",
                message: error.localizedDescription
            )
        }
        loadingState = nil
    }

    private func makeSubtitle(kind: IndexedChunk.Kind, count: Int) -> String {
        switch kind {
        case .qa:
            return "\(count) \(count == 1 ? "pergunta" : "perguntas")"
        case .document, .code:
            return "Importado hoje"
        }
    }

    // MARK: - Remoção e Limpeza

    func removeSource(_ source: MaterialSource) async {
        await removeSource(path: source.path)
    }

    func removeSource(path: String) async {
        do {
            try indexable.removeSource(path)
            sources.removeAll { $0.path == path }
            lastUpdated = Date()
        } catch {
            errorMessage = (
                title: "Erro ao remover material",
                message: error.localizedDescription
            )
        }
    }

    func clearIndex() async {
        do {
            for source in sources {
                try indexable.removeSource(source.path)
            }
            sources.removeAll()
            lastUpdated = nil
            errorMessage = nil
            loadingState = nil
        } catch {
            errorMessage = (
                title: "Erro ao limpar índice",
                message: error.localizedDescription
            )
        }
    }

    func retryLast() async {
        if let lastAttempt {
            await lastAttempt()
        }
    }

    func dismissError() {
        errorMessage = nil
    }
}
