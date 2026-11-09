import SwiftUI

// MARK: - Subviews Auxiliares de Material (DESIGN.md / t04-importacao.html)

struct MaterialEmptyStateView: View {
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
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)

            Text("Importe notas de Q&A, README, documentos ou o repositório. O chat só responde com isso.")
                .font(Typography.bodySm)
                .foregroundStyle(Colors.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.s5)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
    }
}

struct MaterialLoadingCardView: View {
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

struct MaterialSourceRow: View {
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

struct MaterialItemRow: View {
    let title: String
    let subtitle: String
    let value: String

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.s3) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typography.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(Colors.foreground)

                Text(subtitle)
                    .font(Typography.caption)
                    .foregroundStyle(Colors.muted)
            }

            Spacer()

            Text(value)
                .font(Typography.bodySm)
                .foregroundStyle(Colors.muted)
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.vertical, Spacing.s3)
        .frame(minHeight: 56)
    }
}

struct MaterialSourcesListView: View {
    let sources: [MaterialSource]
    let onRemove: (MaterialSource) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                Text("Fontes")
                    .font(Typography.h2)
                    .foregroundStyle(Colors.foreground)
                    .padding(.horizontal, Spacing.s4)

                VStack(spacing: 0) {
                    ForEach(Array(sources.enumerated()), id: \.element.id) { index, source in
                        if index > 0 {
                            Divider().background(Colors.border)
                        }
                        MaterialSourceRow(source: source) {
                            onRemove(source)
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
}

struct MaterialBottomActionsView: View {
    @Bindable var viewModel: MaterialViewModel

    var body: some View {
        switch viewModel.screenState.kind {
        case .vazio:
            importActionsView
        case .carregando:
            PrimaryButton(title: "Indexando...", isLoading: true, isEnabled: false) {}
        case .padrao:
            standardActionsView
        case .pastaConfirmar:
            if let confirmation = viewModel.screenState.folderConfirmation {
                folderConfirmationActionsView(confirmation: confirmation)
            }
        case .pastaIndexando:
            EmptyView()
        case .pastaConcluido:
            importActionsView
        case .pastaErro:
            PrimaryButton(title: "Escolher a pasta de novo") {
                viewModel.chooseAnotherFolder()
            }
            .accessibilityIdentifier("material-choose-folder-again-button")
        case .erro:
            errorActionsView
        }
    }

    private var importActionsView: some View {
        VStack(spacing: Spacing.s2) {
            PrimaryButton(title: "Importar arquivo") {
                viewModel.isPickingFile = true
            }
            .accessibilityIdentifier("material-import-button")

            PrimaryButton(title: "Importar pasta") {
                viewModel.isPickingFolder = true
            }
            .accessibilityIdentifier("material-import-folder-button")
        }
    }

    private var standardActionsView: some View {
        VStack(spacing: Spacing.s2) {
            importActionsView

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
    }

    private func folderConfirmationActionsView(
        confirmation: MaterialScreenState.FolderConfirmationState
    ) -> some View {
        let count = confirmation.validFilesCount
        let countSuffix = count == 1 ? "arquivo" : "arquivos"
        return VStack(spacing: Spacing.s2) {
            PrimaryButton(
                title: "Importar \(formatNumber(count)) \(countSuffix)",
                isEnabled: count > 0
            ) {
                Task {
                    await viewModel.confirmFolderImport()
                }
            }
            .accessibilityIdentifier("material-confirm-folder-button")

            Button {
                viewModel.chooseAnotherFolder()
            } label: {
                Text("Escolher outra pasta")
                    .font(Typography.bodySm)
                    .fontWeight(.semibold)
                    .foregroundStyle(Colors.foreground)
                    .frame(maxWidth: .infinity, minHeight: Spacing.minTouchTarget)
                    .background(Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .stroke(Colors.border, lineWidth: Borders.standard)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Escolher outra pasta")
        }
    }

    private var errorActionsView: some View {
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

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}
