import Foundation
import Observation

/// ViewModel para a aba de Material (T04).
/// Controla o fluxo de importação, estados de tela e comunicação com o índice de busca.
@MainActor
@Observable
final class MaterialViewModel {
    var sources: [MaterialSource] = []
    var lastUpdated: Date?
    var loadingState: MaterialScreenState.LoadingState?
    var errorMessage: (title: String, message: String)?

    var isPickingFile: Bool = false
    var isPickingFolder: Bool = false
    var isShowingClearConfirmation: Bool = false

    var activeFolderState: MaterialScreenState.Kind?
    var currentScanResult: FolderScanResult?
    var folderProgressState: MaterialScreenState.FolderProgressState?
    var folderResultBanner: MaterialScreenState.FolderResultBanner?
    var folderErrorMessage: (title: String, message: String)?
    var folderBadgeTitle: String?

    var indexedFolderFilePaths: Set<String> = []

    let indexable: any MaterialIndexable
    let importer: MaterialImporter
    let fileSource: any MaterialFileSource
    let scanner: any FolderScanning

    var lastAttempt: (@Sendable () async -> Void)?

    init(
        indexable: any MaterialIndexable,
        importer: MaterialImporter = MaterialImporter(),
        fileSource: any MaterialFileSource = DefaultMaterialFileSource(),
        scanner: any FolderScanning = DefaultFolderScanner(),
        initialSources: [MaterialSource] = []
    ) {
        self.indexable = indexable
        self.importer = importer
        self.fileSource = fileSource
        self.scanner = scanner
        self.sources = initialSources
        if !initialSources.isEmpty {
            self.lastUpdated = Date()
        }
    }

    var screenState: MaterialScreenState {
        if let folderState = makeFolderScreenState() {
            return folderState
        }

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

    private func makeFolderScreenState() -> MaterialScreenState? {
        if activeFolderState == .pastaIndexando, let progress = folderProgressState {
            return MaterialScreenState(
                kind: .pastaIndexando,
                badge: MaterialScreenState.BadgeState(status: .ativo, title: "Indexando pasta"),
                sources: sources,
                folderProgress: progress
            )
        }

        if activeFolderState == .pastaConfirmar, let scan = currentScanResult {
            let confirmation = MaterialScreenState.FolderConfirmationState(
                folderName: scan.folderName,
                validFilesCount: scan.validFiles.count,
                qaCount: scan.qaCount,
                documentCount: scan.documentCount,
                codeCount: scan.codeCount,
                ignoredGroups: scan.ignoredGroups
            )
            return MaterialScreenState(kind: .pastaConfirmar, sources: sources, folderConfirmation: confirmation)
        }

        if activeFolderState == .pastaConcluido {
            return MaterialScreenState(
                kind: .pastaConcluido,
                badge: MaterialScreenState.BadgeState(status: .ok, title: folderBadgeTitle ?? "Pasta indexada"),
                sources: sources,
                folderResultBanner: folderResultBanner
            )
        }

        if activeFolderState == .pastaErro, let error = folderErrorMessage {
            let banner = MaterialScreenState.BannerState(
                style: .danger,
                title: error.title,
                message: error.message,
                actionTitle: "Escolher a pasta de novo"
            )
            return MaterialScreenState(kind: .pastaErro, banner: banner, sources: sources)
        }

        return nil
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
            for folderPath in indexedFolderFilePaths {
                try indexable.removeSource(folderPath)
            }
            indexedFolderFilePaths.removeAll()
            sources.removeAll()
            lastUpdated = nil
            errorMessage = nil
            loadingState = nil
            resetFolderState()
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

    /// Recarrega as fontes do material a partir do índice do projeto ativo.
    func reloadForActiveProject() {
        self.sources = indexable.listActiveSources()
        self.lastUpdated = sources.isEmpty ? nil : Date()
        self.loadingState = nil
        self.errorMessage = nil
        self.indexedFolderFilePaths.removeAll()
        self.resetFolderState()
    }

    func dismissError() {
        errorMessage = nil
        folderErrorMessage = nil
        if activeFolderState == .pastaErro {
            activeFolderState = nil
        }
    }

    // MARK: - Gestão de Estado de Pasta

    func updateFolderState(
        activeState: MaterialScreenState.Kind?,
        scanResult: FolderScanResult? = nil,
        progress: MaterialScreenState.FolderProgressState? = nil,
        banner: MaterialScreenState.FolderResultBanner? = nil,
        error: (title: String, message: String)? = nil,
        badgeTitle: String? = nil
    ) {
        self.activeFolderState = activeState
        if let scanResult { self.currentScanResult = scanResult }
        self.folderProgressState = progress
        self.folderResultBanner = banner
        self.folderErrorMessage = error
        if let badgeTitle { self.folderBadgeTitle = badgeTitle }
    }

    func resetFolderState() {
        self.activeFolderState = nil
        self.currentScanResult = nil
        self.folderProgressState = nil
        self.folderResultBanner = nil
        self.folderErrorMessage = nil
        self.folderBadgeTitle = nil
    }

    func replaceFolderSources(with newSources: [MaterialSource]) {
        self.sources.removeAll { $0.path.hasPrefix("folder:") }
        self.sources.append(contentsOf: newSources)
        self.lastUpdated = Date()
    }
}
