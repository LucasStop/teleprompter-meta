import Foundation
import Observation

/// ViewModel da tela de Ensaio (T05).
/// Orquestra o carregamento de itens, verificação de asset STT e execução do ensaio.
@MainActor
@Observable
final class EnsaioViewModel {
    var screenState: EnsaioScreenState = .vazio
    var items: [EnsaioItem] = []
    var isShowingFileImporter: Bool = false
    var isInstallingAsset: Bool = false
    var expandedQuestionId: String?

    private let runner: any EnsaioRunning
    private let itemSource: any EnsaioItemSource
    private let speechAssetManager: (any SpeechAssetManager)?
    private let locale: Locale

    private var currentRunTask: Task<Void, Never>?

    init(
        runner: any EnsaioRunning,
        itemSource: any EnsaioItemSource = DocumentDirectoryEnsaioItemSource(),
        speechAssetManager: (any SpeechAssetManager)? = nil,
        locale: Locale = Locale(identifier: "pt-BR")
    ) {
        self.runner = runner
        self.itemSource = itemSource
        self.speechAssetManager = speechAssetManager
        self.locale = locale
    }

    func loadItems() async {
        do {
            items = try await itemSource.loadItems()
            if items.isEmpty {
                screenState = .vazio
            } else if screenState.kind == .vazio || screenState.kind == .erro {
                screenState = .padrao(
                    summary: EnsaioRunSummary(results: []),
                    questions: []
                )
            }
        } catch {
            screenState = .erro(
                title: "Erro ao carregar perguntas",
                message: "Não foi possível carregar as perguntas da pasta de ensaio: \(error.localizedDescription)",
                actionTitle: "Tentar de novo"
            )
        }
    }

    func startRun() async {
        if items.isEmpty {
            await loadItems()
            if items.isEmpty {
                screenState = .vazio
                return
            }
        }

        guard await validateSpeechReadiness() else { return }

        let firstQuestionTitle = items.first?.title ?? ""
        screenState = .rodando(
            current: 1,
            total: items.count,
            questionTitle: firstQuestionTitle
        )

        currentRunTask?.cancel()
        currentRunTask = Task { @MainActor in
            await executeRun(with: items)
        }

        await currentRunTask?.value
    }

    func cancelRun() {
        runner.cancel()
        currentRunTask?.cancel()
        currentRunTask = nil

        if screenState.kind == .rodando {
            if !items.isEmpty {
                screenState = .padrao(
                    summary: EnsaioRunSummary(results: []),
                    questions: []
                )
            } else {
                screenState = .vazio
            }
        }
    }

    func installSpeechAsset() async {
        guard let manager = speechAssetManager else { return }
        isInstallingAsset = true
        do {
            try await manager.install(for: locale)
            isInstallingAsset = false
            await loadItems()
        } catch {
            isInstallingAsset = false
            screenState = .erro(
                title: "Falha na instalação",
                message: "Não foi possível baixar o modelo de fala: \(error.localizedDescription). Verifique a conexão com a internet.",
                actionTitle: "Tentar de novo"
            )
        }
    }

    func toggleDetails(for questionId: String) {
        if expandedQuestionId == questionId {
            expandedQuestionId = nil
        } else {
            expandedQuestionId = questionId
        }
    }

    func importAudios(from urls: [URL]) async {
        guard let docSource = itemSource as? DocumentDirectoryEnsaioItemSource else { return }
        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: docSource.directoryURL, withIntermediateDirectories: true)
        for url in urls {
            let target = docSource.directoryURL.appendingPathComponent(url.lastPathComponent)
            _ = url.startAccessingSecurityScopedResource()
            defer { url.stopAccessingSecurityScopedResource() }
            try? fileManager.removeItem(at: target)
            try? fileManager.copyItem(at: url, to: target)
        }
        await loadItems()
    }

    // MARK: - Private Helpers

    private func validateSpeechReadiness() async -> Bool {
        let readiness = await runner.checkSpeechReadiness()
        switch readiness {
        case .unsupportedLocale(let unsupported):
            screenState = .erro(
                title: "Reconhecimento de fala indisponível",
                message: "O idioma \(unsupported.identifier) não é suportado pelo transcritor no aparelho.",
                actionTitle: nil
            )
            return false
        case .assetNotInstalled:
            screenState = .erro(
                title: "Modelo de fala não instalado",
                message: "O modelo de reconhecimento de fala em português (pt-BR) não está instalado no dispositivo.",
                actionTitle: "Instalar modelo"
            )
            return false
        case .ready:
            return true
        }
    }

    private func executeRun(with itemsToRun: [EnsaioItem]) async {
        do {
            let (summary, results) = try await runner.run(items: itemsToRun) { [weak self] progress in
                Task { @MainActor in
                    guard let self, self.screenState.kind == .rodando else { return }
                    self.screenState = .rodando(
                        current: progress.currentIndex,
                        total: progress.totalCount,
                        questionTitle: progress.currentQuestionTitle
                    )
                }
            }

            if !Task.isCancelled {
                screenState = .padrao(summary: summary, questions: results)
            }
        } catch is CancellationError {
            if screenState.kind == .rodando {
                screenState = .padrao(
                    summary: EnsaioRunSummary(results: []),
                    questions: []
                )
            }
        } catch {
            screenState = .erro(
                title: "Erro no ensaio",
                message: "Falha durante o ensaio: \(error.localizedDescription)",
                actionTitle: "Tentar de novo"
            )
        }
    }
}
