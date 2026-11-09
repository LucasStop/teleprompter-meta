import Foundation
import SwiftUI

extension Banner.Style: Equatable {}

/// Estado puro da tela de Chat (T02) desacoplado de SwiftUI.
struct ChatScreenState: Equatable, Sendable {
    enum Kind: String, CaseIterable, Equatable, Sendable {
        case vazio
        case digitando
        case escuta
        case pensando
        case conversa
        case semMaterial
        case erro
        case desconectado
    }

    struct BannerState: Equatable, Sendable {
        var style: Banner.Style
        var title: String
        var message: String
        var actionTitle: String?

        init(
            style: Banner.Style,
            title: String,
            message: String,
            actionTitle: String? = nil
        ) {
            self.style = style
            self.title = title
            self.message = message
            self.actionTitle = actionTitle
        }
    }

    struct BadgeState: Equatable, Sendable {
        var status: StatusBadge.Status
        var title: String
    }

    struct MessageItem: Identifiable, Equatable, Sendable {
        let id: String
        var role: MessageBubble.Role
        var text: String
        var bullets: [String]
        var sources: [String]
        var caption: String?
        var isPartial: Bool
        var isSentToLens: Bool
        var isSourcesExpanded: Bool

        init(
            id: String = UUID().uuidString,
            role: MessageBubble.Role,
            text: String,
            bullets: [String] = [],
            sources: [String] = [],
            caption: String? = nil,
            isPartial: Bool = false,
            isSentToLens: Bool = true,
            isSourcesExpanded: Bool = false
        ) {
            self.id = id
            self.role = role
            self.text = text
            self.bullets = bullets
            self.sources = sources
            self.caption = caption
            self.isPartial = isPartial
            self.isSentToLens = isSentToLens
            self.isSourcesExpanded = isSourcesExpanded
        }
    }

    var kind: Kind
    var badge: BadgeState
    var banner: BannerState?
    var messages: [MessageItem]
    var showEmptyPlaceholder: Bool
    var isListening: Bool
    var composerPlaceholder: String
    var suggestionChips: [String]
    var hasMaterial: Bool
    var emptyPlaceholderTitle: String
    var emptyPlaceholderSubtitle: String

    init(
        kind: Kind,
        badge: BadgeState,
        banner: BannerState? = nil,
        messages: [MessageItem] = [],
        showEmptyPlaceholder: Bool = false,
        isListening: Bool = false,
        composerPlaceholder: String = "Pergunte sobre o seu material",
        suggestionChips: [String]? = nil,
        hasMaterial: Bool = true,
        emptyPlaceholderTitle: String? = nil,
        emptyPlaceholderSubtitle: String? = nil
    ) {
        self.kind = kind
        self.badge = badge
        self.banner = banner
        self.messages = messages
        self.showEmptyPlaceholder = showEmptyPlaceholder
        self.isListening = isListening
        self.composerPlaceholder = composerPlaceholder
        self.hasMaterial = hasMaterial
        if hasMaterial {
            self.suggestionChips = suggestionChips ?? [
                "Qual o problema que o app resolve?",
                "Como funciona a busca?"
            ]
            self.emptyPlaceholderTitle = emptyPlaceholderTitle ?? "Pergunte sobre o seu projeto"
            self.emptyPlaceholderSubtitle = emptyPlaceholderSubtitle ??
                "Respondo só com o material que você importou. Digite, toque no microfone ou ligue a escuta contínua."
        } else {
            self.suggestionChips = suggestionChips ?? []
            self.emptyPlaceholderTitle = emptyPlaceholderTitle ?? "Nenhum material neste projeto"
            self.emptyPlaceholderSubtitle = emptyPlaceholderSubtitle ??
                "Cada projeto tem a sua pasta de material e as suas conversas. Depois de criar, importe a pasta na aba Material."
        }
    }
}

// MARK: - Factory / Mapeamento

extension ChatScreenState {
    @MainActor
    init(from viewModel: ConversationViewModel, composerText: String = "") {
        let isTyping = !composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let determinedKind = Self.determineKind(viewModel: viewModel, isTyping: isTyping)
        let (badgeState, bannerState) = Self.makeBadgeAndBanner(
            for: determinedKind,
            errorMessage: viewModel.errorMessage
        )

        self.kind = determinedKind
        self.badge = badgeState
        self.banner = bannerState
        self.isListening = viewModel.isListening
        self.composerPlaceholder = (determinedKind == .escuta) ? "Ouvindo..." : "Pergunte sobre o seu material"
        self.showEmptyPlaceholder = (determinedKind == .vazio || determinedKind == .digitando)
            && viewModel.messages.isEmpty
        self.hasMaterial = viewModel.hasMaterial
        if !viewModel.hasMaterial {
            self.emptyPlaceholderTitle = "Nenhum material neste projeto"
            self.emptyPlaceholderSubtitle =
                "Cada projeto tem a sua pasta de material e as suas conversas. Depois de criar, importe a pasta na aba Material."
            self.suggestionChips = []
        } else {
            self.emptyPlaceholderTitle = "Pergunte sobre o seu projeto"
            self.emptyPlaceholderSubtitle =
                "Respondo só com o material que você importou. Digite, toque no microfone ou ligue a escuta contínua."
            self.suggestionChips = [
                "Qual o problema que o app resolve?",
                "Como funciona a busca?"
            ]
        }
        self.messages = Self.makeMessages(for: determinedKind, viewModel: viewModel)
    }

    @MainActor
    private static func determineKind(viewModel: ConversationViewModel, isTyping: Bool) -> Kind {
        if !viewModel.isGlassesConnected || viewModel.state == .desconectado {
            return .desconectado
        }
        if viewModel.state == .erro {
            return .erro
        }
        if viewModel.isListening || viewModel.state == .ouvindo {
            return .escuta
        }
        if viewModel.state == .pensando {
            return .pensando
        }
        if viewModel.state == .semMaterial {
            return .semMaterial
        }
        if !viewModel.messages.isEmpty {
            return .conversa
        }
        return isTyping ? .digitando : .vazio
    }

    private static func makeBadgeAndBanner(
        for kind: Kind,
        errorMessage: String?
    ) -> (BadgeState, BannerState?) {
        switch kind {
        case .vazio, .digitando:
            return (BadgeState(status: .pronto, title: "Pronto"), nil)
        case .escuta:
            return (BadgeState(status: .ativo, title: "Ouvindo a banca"), nil)
        case .pensando:
            return (BadgeState(status: .ativo, title: "Buscando no material"), nil)
        case .conversa:
            return (BadgeState(status: .ok, title: "Resposta enviada à lente"), nil)
        case .semMaterial:
            return (BadgeState(status: .pronto, title: "Sem resposta no material"), nil)
        case .erro:
            let bannerTitle: String
            let defaultMsg: String
            let isSpeechError: Bool
            if let msg = errorMessage {
                isSpeechError = msg.localizedCaseInsensitiveContains("microfone")
                    || msg.localizedCaseInsensitiveContains("permissão")
                    || msg.localizedCaseInsensitiveContains("fala")
                    || msg.localizedCaseInsensitiveContains("pt-BR")
                    || msg.localizedCaseInsensitiveContains("modelo")
            } else {
                isSpeechError = false
            }

            if isSpeechError, let msg = errorMessage {
                bannerTitle = "Reconhecimento de fala"
                defaultMsg = msg
            } else {
                bannerTitle = "Sem conexão"
                defaultMsg = "Respondendo só com as notas de Q&A. Verifique a rede e tente de novo."
            }
            let banner = BannerState(
                style: .danger,
                title: bannerTitle,
                message: errorMessage ?? defaultMsg
            )
            return (BadgeState(status: .erro, title: bannerTitle), banner)
        case .desconectado:
            let banner = BannerState(
                style: .warning,
                title: "Óculos desconectados",
                message: "A resposta aparece só no iPhone. Reconecte pelo app Meta AI."
            )
            return (BadgeState(status: .erro, title: "Óculos desconectados"), banner)
        }
    }

    @MainActor
    private static func makeMessages(
        for kind: Kind,
        viewModel: ConversationViewModel
    ) -> [MessageItem] {
        var items: [MessageItem] = []

        if kind == .escuta && viewModel.messages.isEmpty {
            items.append(
                MessageItem(
                    role: .answer,
                    text: "Escuta contínua ligada. Detecto o fim da pergunta e respondo sozinho."
                )
            )
        }

        for msg in viewModel.messages {
            items.append(MessageItem(role: .question, text: msg.question))
            items.append(makeAnswerItem(for: msg, isGlassesConnected: viewModel.isGlassesConnected))
        }

        if kind == .pensando {
            if let pending = viewModel.pendingQuestion {
                items.append(MessageItem(role: .question, text: pending))
            }
            items.append(
                MessageItem(
                    role: .answer,
                    text: "Buscando no material...",
                    caption: "Buscando resposta",
                    isSentToLens: false
                )
            )
        }

        if kind == .escuta && !viewModel.currentTranscript.isEmpty {
            items.append(
                MessageItem(
                    role: .partial,
                    text: viewModel.currentTranscript,
                    caption: "Pergunta parcial",
                    isPartial: true
                )
            )
        }

        return items
    }

    private static func makeAnswerItem(for msg: ChatMessage, isGlassesConnected: Bool) -> MessageItem {
        if msg.answer == AnswerPipeline.notFoundMessage {
            return MessageItem(
                role: .answer,
                text: AnswerPipeline.notFoundMessage,
                bullets: ["Importe uma nota ou documento sobre o assunto, ou reformule a pergunta."],
                sources: [],
                caption: "Nada acima do limiar de similaridade",
                isSentToLens: false
            )
        }

        let (intro, bullets) = parseBullets(from: msg.answer)
        let caption = formatCaption(sources: msg.sources, latency: msg.latency)
        let uniqueSources = msg.sources.map(\.path).reduce(into: [String]()) { paths, path in
            if !paths.contains(path) {
                paths.append(path)
            }
        }
        return MessageItem(
            role: .answer,
            text: intro,
            bullets: bullets,
            sources: uniqueSources,
            caption: caption,
            isSentToLens: isGlassesConnected,
            isSourcesExpanded: msg.isSourcesExpanded
        )
    }

    private static func parseBullets(from answer: String) -> (intro: String, bullets: [String]) {
        let lines = answer.components(separatedBy: .newlines)
        var bullets: [String] = []
        var introLines: [String] = []
        let bulletChars: Set<Character> = ["•", "-", "*"]

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            if let first = trimmed.first, bulletChars.contains(first) {
                let cleaned = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                bullets.append(cleaned)
            } else {
                if bullets.isEmpty {
                    introLines.append(trimmed)
                } else {
                    bullets.append(trimmed)
                }
            }
        }

        return (introLines.joined(separator: "\n"), bullets)
    }

    private static func formatCaption(sources: [SourceRef], latency: LatencyReport?) -> String? {
        guard let latency else {
            if sources.contains(where: { $0.path.contains("qa/") }) {
                return "nota de Q&A"
            }
            return sources.first.map { "trecho de \((($0.path as NSString).lastPathComponent))" }
        }

        let latencyStr = String(format: "%.1f s", latency.totalSeconds)
            .replacingOccurrences(of: ".", with: ",")

        if sources.contains(where: { $0.path.contains("qa/") }) {
            return "nota de Q&A · \(latencyStr)"
        }
        if let first = sources.first {
            let fileName = (first.path as NSString).lastPathComponent
            let displayName = fileName.replacingOccurrences(of: ".md", with: "")
            return "trecho de \(displayName) · \(latencyStr)"
        }
        return latencyStr
    }
}

extension ChatScreenState {
    /// Muda quando chega pergunta, resposta ou trecho de streaming; o chat rola ao fim a cada mudança.
    var scrollSignature: Int {
        var hasher = Hasher()
        hasher.combine(messages.count)
        if let last = messages.last {
            hasher.combine(last.text)
            hasher.combine(last.bullets)
            hasher.combine(last.sources)
        }
        return hasher.finalize()
    }
}
