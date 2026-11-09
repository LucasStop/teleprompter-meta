import SwiftUI

/// Tela T03 Configurações (Ajustes) - PRD US-05, US-07, issue #75 e design/prototypes/t03-config.html.
struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s4) {
                    formatSection
                    detectionSection
                    contextSourcesSection
                    llmProviderSection
                    appearanceSection
                    restoreDefaultsSection
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.vertical, Spacing.s4)
            }
            .background(Colors.background.ignoresSafeArea())
            .navigationTitle("Ajustes")
        }
    }
}

// MARK: - Seções de Configuração

extension SettingsView {
    private var formatSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            sectionHeader("Resposta")
            SegmentedChoiceRow(
                items: AnswerFormat.allCases,
                titleFor: \.title,
                selection: $viewModel.format
            )
        }
    }

    private var detectionSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            sectionHeader("Detecção de pergunta")
            VStack(spacing: 0) {
                SettingsSliderRow(
                    title: "Pausa para fim da pergunta",
                    subtitle: "Quanto silêncio encerra a pergunta",
                    value: $viewModel.silenceThreshold,
                    range: Settings.silenceThresholdRange,
                    step: 0.1,
                    isSeconds: true
                )
                Divider().background(Colors.border)
                SettingsSliderRow(
                    title: "Limiar de similaridade (Q&A)",
                    subtitle: "Abaixo disso: \"não encontrei no material\"",
                    value: $viewModel.qaThreshold,
                    range: Settings.qaThresholdRange,
                    step: 0.05,
                    isSeconds: false
                )
                Divider().background(Colors.border)
                SettingsSliderRow(
                    title: "Limiar de similaridade (Trechos)",
                    subtitle: "Para README, documentos e código",
                    value: $viewModel.chunkThreshold,
                    range: Settings.chunkThresholdRange,
                    step: 0.05,
                    isSeconds: false
                )
                Divider().background(Colors.border)
                topKRow
            }
            .background(Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .stroke(Colors.border, lineWidth: Borders.standard)
            )
        }
    }

    private var topKRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.s1) {
                Text("Máximo de trechos")
                    .font(Typography.bodySm)
                    .fontWeight(.semibold)
                    .foregroundStyle(Colors.foreground)
                Text("Limite de contexto para o LLM")
                    .font(Typography.caption)
                    .foregroundStyle(Colors.muted)
            }
            Spacer()
            Stepper(value: $viewModel.topK, in: Settings.topKRange) {
                Text("\(viewModel.topK)")
                    .font(Typography.bodySm)
                    .foregroundStyle(Colors.foreground)
            }
            .accessibilityLabel("Máximo de trechos")
        }
        .padding(Spacing.s4)
    }

    private var contextSourcesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            sectionHeader("Fontes de contexto")
            VStack(spacing: 0) {
                toggleRow(title: "Notas de Q&A", isOn: $viewModel.qaNotesEnabled)
                Divider().background(Colors.border)
                toggleRow(title: "README e documentos", isOn: $viewModel.documentsEnabled)
                Divider().background(Colors.border)
                toggleRow(title: "Código do repositório", isOn: $viewModel.codeEnabled)
            }
            .background(Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .stroke(Colors.border, lineWidth: Borders.standard)
            )
        }
    }

    private func toggleRow(title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(Typography.bodySm)
                .fontWeight(.semibold)
                .foregroundStyle(Colors.foreground)
        }
        .tint(Colors.primary)
        .padding(.horizontal, Spacing.s4)
        .frame(minHeight: 56)
    }

    // MARK: - Provedor de LLM

    private var selectedProviderBinding: Binding<LLMProvider> {
        Binding(
            get: {
                let raw = viewModel.llmProvider.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return LLMProvider(rawValue: raw) ?? .openrouter
            },
            set: { viewModel.llmProvider = $0.rawValue }
        )
    }

    private var llmProviderSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            sectionHeader("Provedor de LLM")
            SegmentedChoiceRow(
                items: LLMProvider.allCases,
                titleFor: \.title,
                selection: selectedProviderBinding
            )

            switch selectedProviderBinding.wrappedValue {
            case .apple:
                appleProviderCard
            case .openrouter:
                openRouterProviderCard
            case .custom:
                customProviderCard
            }
        }
    }

    var hasError: Bool {
        if case .erro = viewModel.state {
            return true
        }
        return viewModel.errorMessage != nil
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            sectionHeader("Aparência")
            SegmentedChoiceRow(
                items: AppearancePreference.allCases,
                titleFor: \.title,
                selection: $viewModel.appearance
            )
        }
    }

    private var restoreDefaultsSection: some View {
        Button {
            viewModel.resetToDefaults()
        } label: {
            Text("Restaurar padrões")
                .font(Typography.bodySm)
                .fontWeight(.semibold)
                .foregroundStyle(Colors.foreground)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(Colors.border, lineWidth: Borders.standard)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Restaurar configurações para os valores padrão")
        .accessibilityIdentifier("settings-restore-defaults-button")
        .padding(.top, Spacing.s2)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(Typography.caption)
            .fontWeight(.semibold)
            .foregroundStyle(Colors.muted)
            .padding(.horizontal, Spacing.s1)
    }
}

// MARK: - Previews

@MainActor
private func previewSettingsView(
    provider: LLMProvider = .openrouter,
    openRouterKey: String? = nil,
    apiKey: String? = nil,
    errorMessage: String? = nil
) -> SettingsView {
    var initialSettings = Settings.default
    initialSettings.llmProvider = provider.rawValue
    let settingsStore = InMemorySettingsStore(initial: initialSettings)
    var secrets: [String: String] = [:]
    if let openRouterKey {
        secrets[SettingsConstants.openRouterApiKeySecretKey] = openRouterKey
    }
    if let apiKey {
        secrets[SettingsConstants.llmApiKeySecretKey] = apiKey
    }
    let secretStore = InMemorySecretStore(initial: secrets)
    let state: SettingsScreenState = errorMessage.map { .erro(message: $0) } ?? .padrao
    let viewModel = SettingsViewModel(
        settingsStore: settingsStore,
        secretStore: secretStore,
        initialState: state
    )
    return SettingsView(viewModel: viewModel)
}

#Preview("OpenRouter Conectado") {
    previewSettingsView(provider: .openrouter, openRouterKey: "sk-or-v1-4f2a").preferredColorScheme(.dark)
}

#Preview("OpenRouter Sem Login") {
    previewSettingsView(provider: .openrouter).preferredColorScheme(.dark)
}

#Preview("OpenRouter Login Erro") {
    let err = "Login cancelado ou recusado. Tente de novo."
    return previewSettingsView(provider: .openrouter, errorMessage: err).preferredColorScheme(.dark)
}

#Preview("Apple no aparelho") {
    previewSettingsView(provider: .apple).preferredColorScheme(.dark)
}

#Preview("Personalizado Padrão") {
    previewSettingsView(provider: .custom, apiKey: "sk-groq-4f2a").preferredColorScheme(.dark)
}

#Preview("Personalizado Erro") {
    let err = "Chave recusada pelo provedor. Confira e salve de novo."
    return previewSettingsView(provider: .custom, errorMessage: err).preferredColorScheme(.dark)
}
