import SwiftUI
import UniformTypeIdentifiers

/// Aba principal de Material (T04) no iPhone.
/// Apenas renderiza e delega ações para o `MaterialViewModel`.
struct MaterialView: View {
    @Bindable var viewModel: MaterialViewModel

    init(viewModel: MaterialViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerView
                    .padding(.horizontal, Spacing.s4)
                    .padding(.top, Spacing.s4)
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
                    Banner(
                        style: banner.style,
                        title: banner.title,
                        message: banner.message,
                        actionTitle: banner.actionTitle,
                        action: {
                            Task {
                                await viewModel.retryLast()
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

                contentView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                bottomActionsView
                    .padding(.horizontal, Spacing.s4)
                    .padding(.vertical, Spacing.s3)
            }
            .background(Colors.background)
            .fileImporter(
                isPresented: $viewModel.isPickingFile,
                allowedContentTypes: supportedContentTypes,
                allowsMultipleSelection: false
            ) { result in
                handleFileImportResult(result)
            }
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

    @ViewBuilder
    private var contentView: some View {
        switch viewModel.screenState.kind {
        case .vazio:
            MaterialEmptyStateView()
        case .carregando:
            if let loading = viewModel.screenState.loading {
                MaterialLoadingCardView(loading: loading)
            }
        case .padrao, .erro:
            if viewModel.sources.isEmpty {
                MaterialEmptyStateView()
            } else {
                sourcesListView
            }
        }
    }

    private var sourcesListView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                Text("Fontes")
                    .font(Typography.h2)
                    .foregroundStyle(Colors.foreground)
                    .padding(.horizontal, Spacing.s4)

                VStack(spacing: 0) {
                    ForEach(Array(viewModel.sources.enumerated()), id: \.element.id) { index, source in
                        if index > 0 {
                            Divider()
                                .background(Colors.border)
                        }
                        MaterialSourceRow(source: source) {
                            Task {
                                await viewModel.removeSource(source)
                            }
                        }
                    }
                }
                .background(Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(Colors.border, lineWidth: Borders.standard)
                )
                .padding(.horizontal, Spacing.s4)
            }
        }
    }

    @ViewBuilder
    private var bottomActionsView: some View {
        switch viewModel.screenState.kind {
        case .vazio:
            PrimaryButton(title: "Importar material") {
                viewModel.isPickingFile = true
            }
            .accessibilityIdentifier("material-import-button")
        case .carregando:
            PrimaryButton(title: "Indexando...", isLoading: true, isEnabled: false) {}
        case .padrao:
            VStack(spacing: Spacing.s2) {
                PrimaryButton(title: "Importar material") {
                    viewModel.isPickingFile = true
                }
                .accessibilityIdentifier("material-import-button")

                Button(role: .destructive) {
                    viewModel.isShowingClearConfirmation = true
                } label: {
                    Text("Limpar índice")
                        .font(Typography.bodySm)
                        .fontWeight(.semibold)
                        .foregroundStyle(Colors.danger)
                        .frame(maxWidth: .infinity, minHeight: Spacing.minTouchTarget)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Limpar índice")
            }
        case .erro:
            VStack(spacing: Spacing.s2) {
                PrimaryButton(title: "Tentar de novo") {
                    Task {
                        await viewModel.retryLast()
                    }
                }

                Button {
                    viewModel.isPickingFile = true
                } label: {
                    Text("Importar outro arquivo")
                        .font(Typography.bodySm)
                        .fontWeight(.semibold)
                        .foregroundStyle(Colors.primary)
                        .frame(maxWidth: .infinity, minHeight: Spacing.minTouchTarget)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var supportedContentTypes: [UTType] {
        var types: [UTType] = [.text, .plainText, .utf8PlainText, .sourceCode]
        if let mdType = UTType(filenameExtension: "md") {
            types.append(mdType)
        }
        if let swiftType = UTType(filenameExtension: "swift") {
            types.append(swiftType)
        }
        if let tsType = UTType(filenameExtension: "ts") {
            types.append(tsType)
        }
        if let phpType = UTType(filenameExtension: "php") {
            types.append(phpType)
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
}

// MARK: - Subviews Auxiliares

private struct MaterialEmptyStateView: View {
    var body: some View {
        VStack(spacing: Spacing.s3) {
            Spacer()

            Image(systemName: "doc.text")
                .font(.system(size: 44))
                .foregroundStyle(Colors.muted)
                .accessibilityHidden(true)

            Text("Nenhum material importado")
                .font(Typography.h3)
                .foregroundStyle(Colors.foreground)
                .accessibilityIdentifier("material-empty-title")

            Text("Importe notas de Q&A, README, documentos ou o repositório. O chat só responde com isso.")
                .font(Typography.bodySm)
                .foregroundStyle(Colors.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.s5)

            Spacer()
        }
    }
}

private struct MaterialLoadingCardView: View {
    let loading: MaterialScreenState.LoadingState

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            VStack(alignment: .leading, spacing: Spacing.s2) {
                Text(loading.sourceName)
                    .font(Typography.body)
                    .fontWeight(.bold)
                    .foregroundStyle(Colors.foreground)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Colors.border)
                            .frame(height: 6)

                        Capsule()
                            .fill(Colors.primary)
                            .frame(
                                width: max(6, geo.size.width * CGFloat(max(0.05, min(1.0, loading.progress)))),
                                height: 6
                            )
                    }
                }
                .frame(height: 6)
                .accessibilityLabel("Progresso da indexação")
                .accessibilityValue("\(Int(loading.progress * 100)) por cento")

                Text("\(loading.current) de \(loading.total) trechos")
                    .font(Typography.caption)
                    .foregroundStyle(Colors.muted)
            }
            .padding(Spacing.s4)
            .background(Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .stroke(Colors.border, lineWidth: Borders.standard)
            )
            .padding(.horizontal, Spacing.s4)

            Spacer()
        }
        .padding(.top, Spacing.s2)
    }
}

private struct MaterialSourceRow: View {
    let source: MaterialSource
    let onRemove: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.s3) {
            VStack(alignment: .leading, spacing: Spacing.s1) {
                Text(source.name)
                    .font(Typography.body)
                    .fontWeight(.bold)
                    .foregroundStyle(Colors.foreground)

                Text(source.subtitle)
                    .font(Typography.caption)
                    .foregroundStyle(Colors.muted)
            }

            Spacer()

            Text(source.displayCount)
                .font(Typography.bodySm)
                .foregroundStyle(Colors.muted)

            Button(role: .destructive, action: onRemove) {
                Image(systemName: "trash")
                    .font(.system(size: 15))
                    .foregroundStyle(Colors.danger)
                    .frame(width: Spacing.minTouchTarget, height: Spacing.minTouchTarget)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remover \(source.name)")
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.vertical, Spacing.s2)
    }
}
