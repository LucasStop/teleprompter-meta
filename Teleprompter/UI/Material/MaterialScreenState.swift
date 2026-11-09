import Foundation

/// Estado puro da tela de Material (T04) desacoplado de SwiftUI.
struct MaterialScreenState: Equatable, Sendable {
    enum Kind: String, CaseIterable, Equatable, Sendable {
        case vazio
        case padrao
        case carregando
        case erro
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

    struct LoadingState: Equatable, Sendable {
        var sourceName: String
        var current: Int
        var total: Int
        var progress: Double
    }

    var kind: Kind
    var badge: BadgeState?
    var banner: BannerState?
    var sources: [MaterialSource]
    var loading: LoadingState?

    init(
        kind: Kind,
        badge: BadgeState? = nil,
        banner: BannerState? = nil,
        sources: [MaterialSource] = [],
        loading: LoadingState? = nil
    ) {
        self.kind = kind
        self.badge = badge
        self.banner = banner
        self.sources = sources
        self.loading = loading
    }
}
