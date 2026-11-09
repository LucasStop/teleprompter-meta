import SwiftUI
import UniformTypeIdentifiers

/// Aba principal de Material (T04) no iPhone.
/// Apenas renderiza e delega ações para o `MaterialViewModel`.
struct MaterialView: View {
    @Bindable var viewModel: MaterialViewModel
    var activeProjectName: String
    var onOpenProjects: (() -> Void)?

    init(
        viewModel: MaterialViewModel,
        activeProjectName: String = Project.defaultName,
        onOpenProjects: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.activeProjectName = activeProjectName
        self.onOpenProjects = onOpenProjects
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerView
                    .padding(.horizontal, Spacing.s4)
                    .padding(.top, Spacing.s4)
                    .padding(.bottom, Spacing.s1)

                ProjectLine(projectName: activeProjectName, action: onOpenProjects)
                    .padding(.horizontal, Spacing.s4)
                    .padding(.bottom, Spacing.s2)

                if let badge = viewModel.screenState.badge {
                    HStack {
                        StatusBadge(status: badge.status, title: badge.title)
                        Spacer()
                    }
                    .padding(.horizontal, Spacing.s4)
                    .padding(.bottom, Spacing.s3)
                }

                if let banner = viewModel.screenState.banner {
                    bannerView(banner)
                }

                contentView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .fileImporter(
                        isPresented: $viewModel.isPickingFile,
                        allowedContentTypes: supportedContentTypes,
                        allowsMultipleSelection: false
                    ) { result in
                        handleFileImportResult(result)
                    }

                MaterialBottomActionsView(viewModel: viewModel)
                    .padding(.horizontal, Spacing.s4)
                    .padding(.vertical, Spacing.s3)
                    .fileImporter(
                        isPresented: $viewModel.isPickingFolder,
                        allowedContentTypes: [.folder],
                        allowsMultipleSelection: false
                    ) { result in
                        handleFolderImportResult(result)
                    }
            }
            .background(Colors.background)
            .confirmationDialog(
                "Limpar todo o índice?",
                isPresented: $viewModel.isShowingClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Limpar índice", role: .destructive) {
                    Task {
                        await viewModel.clearIndex()
                    }
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Isso remove todos os trechos indexados do aparelho. O chat não poderá responder sem material.")
            }
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            Text("Material")
                .font(Typography.h1)
                .foregroundStyle(Colors.foreground)
                .accessibilityIdentifier("material-title")
            Spacer()
        }
    }

    private func bannerView(_ banner: MaterialScreenState.BannerState) -> some View {
        Banner(
            style: banner.style,
            title: banner.title,
            message: banner.message,
            actionTitle: banner.actionTitle,
            action: {
                if viewModel.screenState.kind == .pastaErro {
                    viewModel.chooseAnotherFolder()
                } else {
                    Task {
                        await viewModel.retryLast()
                    }
                }
            },
            onDismiss: {
                viewModel.dismissError()
            }
        )
        .padding(.horizontal, Spacing.s4)
        .padding(.bottom, Spacing.s3)
        .transition(.opacity)
    }

    @ViewBuilder
    private var contentView: some View {
        switch viewModel.screenState.kind {
        case .vazio:
            MaterialEmptyStateView()
        case .carregando:
            if let loading = viewModel.screenState.loading {
                MaterialLoadingCardView(loading: loading)
            }
        case .padrao:
            MaterialSourcesListView(sources: viewModel.sources) { source in
                Task { await viewModel.removeSource(source) }
            }
        case .erro, .pastaErro:
            if viewModel.sources.isEmpty {
                MaterialEmptyStateView()
            } else {
                MaterialSourcesListView(sources: viewModel.sources) { source in
                    Task { await viewModel.removeSource(source) }
                }
            }
        case .pastaConfirmar:
            if let confirmation = viewModel.screenState.folderConfirmation {
                FolderConfirmationContentView(confirmation: confirmation)
            }
        case .pastaIndexando:
            if let progress = viewModel.screenState.folderProgress {
                FolderProgressContentView(progress: progress)
            }
        case .pastaConcluido:
            FolderConcluidoContentView(
                sources: viewModel.sources,
                banner: viewModel.screenState.folderResultBanner,
                onRemoveSource: { source in
                    Task { await viewModel.removeSource(source) }
                }
            )
        }
    }

    private var supportedContentTypes: [UTType] {
        var types: [UTType] = [.text, .plainText, .utf8PlainText, .sourceCode]
        let extensions = ["md", "swift", "ts", "tsx", "js", "php", "py", "json", "yml", "yaml"]
        for ext in extensions {
            if let utType = UTType(filenameExtension: ext) {
                types.append(utType)
            }
        }
        return types
    }

    private func handleFileImportResult(_ result: Result<[URL], any Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                Task {
                    await viewModel.importFile(from: url)
                }
            }
        case .failure:
            Task {
                await viewModel.importFile(from: URL(fileURLWithPath: "arquivo_selecionado"))
            }
        }
    }

    private func handleFolderImportResult(_ result: Result<[URL], any Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                Task {
                    await viewModel.selectFolder(url: url)
                }
            }
        case .failure:
            Task {
                await viewModel.selectFolder(url: URL(fileURLWithPath: "pasta_selecionada"))
            }
        }
    }
}
