import Foundation

/// Estado puro da tela de Material (T04) desacoplado de SwiftUI.
struct MaterialScreenState: Equatable, Sendable {
    enum Kind: String, CaseIterable, Equatable, Sendable {
        case vazio
        case padrao
        case carregando
        case erro
        case pastaConfirmar
        case pastaIndexando
        case pastaConcluido
        case pastaErro
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

    struct FolderConfirmationState: Equatable, Sendable {
        var folderName: String
        var validFilesCount: Int
        var qaCount: Int
        var documentCount: Int
        var codeCount: Int
        var ignoredGroups: [IgnoredGroup]
    }

    struct FolderProgressState: Equatable, Sendable {
        var folderName: String
        var current: Int
        var total: Int
        var currentFileName: String
        var progress: Double
    }

    struct FolderResultBanner: Equatable, Sendable {
        var ignoredCount: Int
        var message: String
    }

    var kind: Kind
    var badge: BadgeState?
    var banner: BannerState?
    var sources: [MaterialSource]
    var loading: LoadingState?
    var folderConfirmation: FolderConfirmationState?
    var folderProgress: FolderProgressState?
    var folderResultBanner: FolderResultBanner?

    init(
        kind: Kind,
        badge: BadgeState? = nil,
        banner: BannerState? = nil,
        sources: [MaterialSource] = [],
        loading: LoadingState? = nil,
        folderConfirmation: FolderConfirmationState? = nil,
        folderProgress: FolderProgressState? = nil,
        folderResultBanner: FolderResultBanner? = nil
    ) {
        self.kind = kind
        self.badge = badge
        self.banner = banner
        self.sources = sources
        self.loading = loading
        self.folderConfirmation = folderConfirmation
        self.folderProgress = folderProgress
        self.folderResultBanner = folderResultBanner
    }
}
