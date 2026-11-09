import SwiftUI

// MARK: - Cards de Provedores de LLM (T03 Configurações)

extension SettingsView {
    var appleProviderCard: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            Text("Modelo no aparelho")
                .font(Typography.bodySm)
                .fontWeight(.bold)
                .foregroundStyle(Colors.foreground)

            Text("Sem rede e sem chave: a pergunta não sai do iPhone. Exige Apple Intelligence ligado.")
                .font(Typography.caption)
                .foregroundStyle(Colors.muted)

            if !viewModel.isAppleSupported {
                Text("Apple Intelligence indisponível neste dispositivo.")
                    .font(Typography.caption)
                    .foregroundStyle(Colors.muted)
            }
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.vertical, Spacing.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .stroke(Colors.border, lineWidth: Borders.standard)
        )
    }

    var openRouterProviderCard: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            if viewModel.hasSavedOpenRouterApiKey {
                HStack {
                    VStack(alignment: .leading, spacing: Spacing.s1) {
                        Text("Conectado ao OpenRouter")
                            .font(Typography.bodySm)
                            .fontWeight(.bold)
                            .foregroundStyle(Colors.foreground)
                        Text(viewModel.maskedOpenRouterApiKey ?? "Chave no Keychain")
                            .font(Typography.caption)
                            .foregroundStyle(Colors.muted)
                    }
                    Spacer()
                    Button {
                        viewModel.removeOpenRouterApiKey()
                    } label: {
                        Text("Sair")
                            .font(Typography.bodySm)
                            .foregroundStyle(Colors.muted)
                            .frame(minHeight: Spacing.minTouchTarget)
                            .padding(.horizontal, Spacing.s2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Sair da conta OpenRouter")
                    .accessibilityIdentifier("openrouter-logout-button")
                }
            } else {
                Button {
                    Task {
                        await viewModel.startOpenRouterLogin()
                    }
                } label: {
                    HStack {
                        if viewModel.isOpenRouterAuthenticating {
                            ProgressView()
                                .tint(Colors.primaryForeground)
                                .padding(.trailing, Spacing.s2)
                        }
                        Text("Entrar com OpenRouter")
                            .font(Typography.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(Colors.primaryForeground)
                    }
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Colors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isOpenRouterAuthenticating)
                .accessibilityLabel("Entrar com OpenRouter")
                .accessibilityIdentifier("openrouter-login-button")

                Text("Abre o login do OpenRouter; a chave volta direto para o Keychain.")
                    .font(Typography.caption)
                    .foregroundStyle(Colors.muted)

                if hasError {
                    Text(viewModel.errorMessage ?? "Login cancelado ou recusado. Tente de novo.")
                        .font(Typography.caption)
                        .foregroundStyle(Colors.danger)
                        .accessibilityLabel("Mensagem de erro: \(viewModel.errorMessage ?? "")")
                }
            }

            Text("Modelo")
                .font(Typography.caption)
                .foregroundStyle(Colors.muted)
                .padding(.top, Spacing.s1)

            TextField("anthropic/claude-haiku-5.5", text: $viewModel.llmModel)
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
                .accessibilityLabel("Modelo do LLM OpenRouter")
                .accessibilityIdentifier("openrouter-model-field")
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.vertical, Spacing.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .stroke(hasError ? Colors.danger : Colors.border, lineWidth: Borders.standard)
        )
    }

    var customProviderCard: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            Text("Formato")
                .font(Typography.caption)
                .foregroundStyle(Colors.muted)

            SegmentedChoiceRow(
                items: LLMFormat.allCases,
                titleFor: \.title,
                selection: Binding(
                    get: { LLMFormat(rawValue: viewModel.llmFormat) ?? .openai },
                    set: { viewModel.llmFormat = $0.rawValue }
                )
            )

            Text("URL base")
                .font(Typography.caption)
                .foregroundStyle(Colors.muted)
                .padding(.top, Spacing.s1)

            TextField("https://api.groq.com/openai/v1", text: $viewModel.llmBaseURL)
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
                .accessibilityIdentifier("custom-base-url-field")

            Text("Modelo")
                .font(Typography.caption)
                .foregroundStyle(Colors.muted)
                .padding(.top, Spacing.s1)

            TextField("llama-3.3-70b-versatile", text: $viewModel.llmModel)
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
                .accessibilityIdentifier("custom-model-field")

            Text("Chave de API (Keychain)")
                .font(Typography.caption)
                .foregroundStyle(Colors.muted)
                .padding(.top, Spacing.s1)

            apiKeyContentRow

            if hasError {
                Text(viewModel.errorMessage ?? "Chave recusada pelo provedor. Confira e salve de novo.")
                    .font(Typography.caption)
                    .foregroundStyle(Colors.danger)
                    .accessibilityLabel("Mensagem de erro: \(viewModel.errorMessage ?? "")")
            }
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.vertical, Spacing.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .stroke(hasError ? Colors.danger : Colors.border, lineWidth: Borders.standard)
        )
    }

    @ViewBuilder
    var apiKeyContentRow: some View {
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
}
