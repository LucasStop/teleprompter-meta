import Foundation

// MARK: - Fábricas de Geradores de LLM

extension AppEnvironment {
    static func makeGenerator(
        settings: Settings,
        secretStore: any SecretStore
    ) -> (any AnswerGenerator)? {
        let provider = settings.llmProvider.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        switch provider {
        case "apple":
            return makeAppleGenerator()
        case "openrouter":
            return makeOpenRouterGenerator(settings: settings, secretStore: secretStore)
        case "custom", "openai", "anthropic":
            return makeCustomGenerator(settings: settings, secretStore: secretStore, provider: provider)
        default:
            return nil
        }
    }

    private static func makeAppleGenerator() -> (any AnswerGenerator)? {
        guard FoundationModelsAnswerGenerator.isSupported else { return nil }
        return FoundationModelsAnswerGenerator()
    }

    private static func makeOpenRouterGenerator(
        settings: Settings,
        secretStore: any SecretStore
    ) -> (any AnswerGenerator)? {
        guard let key = try? secretStore.get(key: SettingsConstants.openRouterApiKeySecretKey),
              !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let url = URL(string: "https://openrouter.ai/api/v1") else {
            return nil
        }
        let trimmedModel = settings.llmModel.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = trimmedModel.isEmpty ? "anthropic/claude-haiku-5.5" : trimmedModel

        return StreamingAnswerGenerator(
            baseURL: url,
            model: model,
            secretStore: secretStore,
            apiKeyKey: SettingsConstants.openRouterApiKeySecretKey,
            format: .openAI
        )
    }

    private static func makeCustomGenerator(
        settings: Settings,
        secretStore: any SecretStore,
        provider: String
    ) -> (any AnswerGenerator)? {
        guard let key = try? secretStore.get(key: SettingsConstants.llmApiKeySecretKey),
              !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let trimmedBaseURL = settings.llmBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBaseURL.isEmpty,
              let url = URL(string: trimmedBaseURL),
              url.scheme != nil, let host = url.host, !host.isEmpty else { return nil }
        let trimmedModel = settings.llmModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedModel.isEmpty else { return nil }

        let formatString = provider == "anthropic" ? "anthropic" : (provider == "openai" ? "openai" : settings.llmFormat)
        let isAnthropic = formatString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "anthropic"
        let format: StreamingAnswerGenerator.Format = isAnthropic ? .anthropic : .openAI

        return StreamingAnswerGenerator(
            baseURL: url,
            model: trimmedModel,
            secretStore: secretStore,
            apiKeyKey: SettingsConstants.llmApiKeySecretKey,
            format: format
        )
    }
}
