import SwiftUI

/// Tela T03 Configurações (Ajustes) - PRD US-05, US-07 e design/prototypes/t03-config.html.
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

    private var llmProviderSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            sectionHeader("Provedor de LLM")
            VStack(alignment: .leading, spacing: Spacing.s3) {
                Text("Provedor")
                    .font(Typography.caption)
                    .foregroundStyle(Colors.muted)

                SegmentedChoiceRow(
                    items: LLMProviderOption.allCases,
                    titleFor: \.title,
                    selection: Binding(
                        get: {
                            let provider = viewModel.llmProvider.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                            return provider == "anthropic" ? .anthropic : .openai
                        },
                        set: { viewModel.llmProvider = $0.rawValue }
                    )
                )

                Divider().background(Colors.border)

                Text("URL Base")
                    .font(Typography.caption)
                    .foregroundStyle(Colors.muted)

                TextField("https://api.openai.com/v1", text: $viewModel.llmBaseURL)
                    .font(Typography.bodySm)
                    .foregroundStyle(Colors.foreground)
                    .padding(.horizontal, Spacing.s3)
                    .frame(minHeight: Spacing.minTouchTarget)
                    .background(Colors.background)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .stroke(Colors.border, lineWidth: Borders.standard)
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityLabel("URL Base do LLM")

                Divider().background(Colors.border)

                Text("Modelo")
                    .font(Typography.caption)
                    .foregroundStyle(Colors.muted)

                TextField("gpt-4o-mini", text: $viewModel.llmModel)
                    .font(Typography.bodySm)
                    .foregroundStyle(Colors.foreground)
                    .padding(.horizontal, Spacing.s3)
                    .frame(minHeight: Spacing.minTouchTarget)
                    .background(Colors.background)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .stroke(Colors.border, lineWidth: Borders.standard)
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityLabel("Modelo do LLM")

                Divider().background(Colors.border)

                Text("Chave de API (Keychain)")
                    .font(Typography.caption)
                    .foregroundStyle(Colors.muted)

                apiKeyContentRow

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(Typography.caption)
                        .foregroundStyle(Colors.danger)
                        .accessibilityLabel("Mensagem de erro: \(errorMessage)")
                }
            }
            .padding(Spacing.s4)
            .background(Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .stroke(hasError ? Colors.danger : Colors.border, lineWidth: Borders.standard)
            )
        }
    }

    @ViewBuilder
    private var apiKeyContentRow: some View {
        if viewModel.hasSavedApiKey {
            HStack(spacing: Spacing.s3) {
                Text(viewModel.maskedApiKey ?? "Chave salva")
                    .font(Typography.bodySm)
                    .foregroundStyle(Colors.foreground)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.s3)
                    .frame(minHeight: Spacing.minTouchTarget)
                    .background(Colors.background)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .stroke(hasError ? Colors.danger : Colors.border, lineWidth: Borders.standard)
                    )

                Button(role: .destructive) {
                    viewModel.removeApiKey()
                } label: {
                    Text("Remover")
                        .font(Typography.bodySm)
                        .fontWeight(.semibold)
                        .foregroundStyle(Colors.danger)
                        .frame(minHeight: Spacing.minTouchTarget)
                        .padding(.horizontal, Spacing.s3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remover chave de API do Keychain")
            }
        } else {
            HStack(spacing: Spacing.s3) {
                SecureField("sk-••••••••", text: $viewModel.apiKeyInput)
                    .font(Typography.bodySm)
                    .foregroundStyle(Colors.foreground)
                    .padding(.horizontal, Spacing.s3)
                    .frame(minHeight: Spacing.minTouchTarget)
                    .background(Colors.background)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .stroke(hasError ? Colors.danger : Colors.border, lineWidth: Borders.standard)
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityLabel("Campo de chave de API")

                Button {
                    viewModel.saveApiKey()
                } label: {
                    Text("Salvar")
                        .font(Typography.bodySm)
                        .fontWeight(.semibold)
                        .foregroundStyle(Colors.primaryForeground)
                        .padding(.horizontal, Spacing.s4)
                        .frame(minHeight: Spacing.minTouchTarget)
                        .background(Colors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Salvar chave de API no Keychain")
            }
        }
    }

    private var hasError: Bool {
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
private func previewSettingsView(apiKey: String? = nil, errorMessage: String? = nil) -> SettingsView {
    let settingsStore = InMemorySettingsStore()
    let secretStore = InMemorySecretStore(
        initial: apiKey.map { [SettingsConstants.llmApiKeySecretKey: $0] } ?? [:]
    )
    let state: SettingsScreenState = errorMessage.map { .erro(message: $0) } ?? .padrao
    let viewModel = SettingsViewModel(
        settingsStore: settingsStore,
        secretStore: secretStore,
        initialState: state
    )
    return SettingsView(viewModel: viewModel)
}

#Preview("Padrão - Claro") {
    previewSettingsView(apiKey: "sk-proj-4f2a").preferredColorScheme(.light)
}

#Preview("Padrão - Escuro") {
    previewSettingsView(apiKey: "sk-proj-4f2a").preferredColorScheme(.dark)
}

#Preview("Erro - Claro") {
    previewSettingsView(errorMessage: "Chave recusada pelo provedor. Confira e salve de novo.").preferredColorScheme(.light)
}

#Preview("Erro - Escuro") {
    previewSettingsView(errorMessage: "Chave recusada pelo provedor. Confira e salve de novo.").preferredColorScheme(.dark)
}
