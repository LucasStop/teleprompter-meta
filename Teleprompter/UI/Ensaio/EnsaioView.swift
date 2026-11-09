import SwiftUI
import UniformTypeIdentifiers

/// Tela principal da aba Ensaio (T05) no iPhone.
/// Executa as perguntas gravadas pelo pipeline e exibe WER e latência por etapa.
struct EnsaioView: View {
    @Bindable var viewModel: EnsaioViewModel

    init(viewModel: EnsaioViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerView
                    .padding(.horizontal, Spacing.s4)
                    .padding(.top, Spacing.s4)
                    .padding(.bottom, Spacing.s2)

                contentView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                bottomActionsView
                    .padding(.horizontal, Spacing.s4)
                    .padding(.vertical, Spacing.s3)
            }
            .background(Colors.background)
            .fileImporter(
                isPresented: $viewModel.isShowingFileImporter,
                allowedContentTypes: [.audio, .plainText],
                allowsMultipleSelection: true
            ) { result in
                if case .success(let urls) = result {
                    Task { await viewModel.importAudios(from: urls) }
                }
            }
            .task {
                await viewModel.loadItems()
            }
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            Text("Ensaio")
                .font(Typography.h1)
                .foregroundStyle(Colors.foreground)
                .accessibilityIdentifier("ensaio-title")
            Spacer()
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch viewModel.screenState.kind {
        case .vazio:
            emptyStateView
        case .rodando:
            if let running = viewModel.screenState.running {
                runningStateView(running: running)
            }
        case .padrao:
            standardStateView
        case .erro:
            if let error = viewModel.screenState.error {
                errorStateView(error: error)
            }
        }
    }

    // MARK: - Estado Vazio

    private var emptyStateView: some View {
        VStack(spacing: Spacing.s3) {
            Spacer()

            Image(systemName: "waveform")
                .font(.system(size: 48))
                .foregroundStyle(Colors.muted)

            Text("Sem perguntas gravadas")
                .font(Typography.h2)
                .foregroundStyle(Colors.foreground)
                .accessibilityIdentifier("ensaio-empty-title")

            Text("Adicione áudios das perguntas da banca para ensaiar sem os óculos.")
                .font(Typography.bodySm)
                .foregroundStyle(Colors.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.s5)
                .accessibilityIdentifier("ensaio-empty-instruction")
                .minimumScaleFactor(0.75)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Estado Rodando

    private func runningStateView(running: EnsaioScreenState.Running) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            StatusBadge(status: .ativo, title: running.badgeText)

            EnsaioProgressBar(fraction: running.progress)

            VStack(alignment: .leading, spacing: Spacing.s1) {
                Text("Pergunta atual")
                    .font(Typography.caption)
                    .foregroundStyle(Colors.muted)

                Text(running.currentQuestionTitle)
                    .font(Typography.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(Colors.foreground)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.s4)
            .background(Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .stroke(Colors.border, lineWidth: Borders.standard)
            )

            Spacer()
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.top, Spacing.s2)
    }

    // MARK: - Estado Padrão (Resultados)

    private var standardStateView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                if let summary = viewModel.screenState.summary, summary.totalQuestions > 0 {
                    EnsaioSummaryCardView(summary: summary)
                }

                if !viewModel.screenState.questions.isEmpty {
                    Text("PERGUNTAS")
                        .font(Typography.caption)
                        .foregroundStyle(Colors.muted)
                        .padding(.top, Spacing.s2)

                    VStack(spacing: 0) {
                        ForEach(viewModel.screenState.questions) { question in
                            EnsaioQuestionRowView(
                                question: question,
                                isExpanded: viewModel.expandedQuestionId == question.id,
                                onToggle: { viewModel.toggleDetails(for: question.id) }
                            )

                            if question.id != viewModel.screenState.questions.last?.id {
                                Divider().background(Colors.border)
                            }
                        }
                    }
                    .background(Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .stroke(Colors.border, lineWidth: Borders.standard)
                    )
                }
            }
            .padding(.horizontal, Spacing.s4)
            .padding(.top, Spacing.s2)
            .padding(.bottom, Spacing.s4)
        }
    }

    // MARK: - Estado de Erro

    private func errorStateView(error: EnsaioScreenState.ErrorState) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            Banner(
                style: .danger,
                title: error.title,
                message: error.message,
                actionTitle: error.actionTitle,
                action: {
                    Task {
                        if error.actionTitle == "Instalar modelo" {
                            await viewModel.installSpeechAsset()
                        } else {
                            await viewModel.startRun()
                        }
                    }
                }
            )

            Spacer()
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.top, Spacing.s2)
    }

    // MARK: - Ações Inferiores

    @ViewBuilder
    private var bottomActionsView: some View {
        switch viewModel.screenState.kind {
        case .vazio:
            PrimaryButton(title: "Adicionar áudios") {
                viewModel.isShowingFileImporter = true
            }
            .accessibilityIdentifier("ensaio-add-audios-button")

        case .rodando:
            Button {
                viewModel.cancelRun()
            } label: {
                Text("Parar ensaio")
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
            .accessibilityLabel("Parar ensaio")

        case .padrao:
            PrimaryButton(title: "Ensaiar tudo") {
                Task { await viewModel.startRun() }
            }

        case .erro:
            let title = viewModel.screenState.error?.actionTitle ?? "Tentar de novo"
            PrimaryButton(title: title) {
                Task {
                    if title == "Instalar modelo" {
                        await viewModel.installSpeechAsset()
                    } else {
                        await viewModel.startRun()
                    }
                }
            }
        }
    }
}
