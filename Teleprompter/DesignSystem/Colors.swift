import SwiftUI
import UIKit

/// Tokens semânticos de cor (DESIGN.md 3.1) com resolução dinâmica para modo claro e escuro.
public enum SemanticColor: String, CaseIterable, Sendable {
    case background
    case surface
    case surfaceRaised = "surface-raised"
    case foreground
    case muted
    case border
    case primary
    case primaryHover = "primary-hover"
    case primaryForeground = "primary-foreground"
    case success
    case warning
    case danger
    case info
    case focusRing = "focus-ring"
    case disabled
    case userBubble = "user-bubble"

    public var lightHex: String {
        switch self {
        case .background: return "#FAF8F4"
        case .surface: return "#FFFFFF"
        case .surfaceRaised: return "#FFFFFF"
        case .foreground: return "#1C1B19"
        case .muted: return "#5F5B54"
        case .border: return "#DDD8CF"
        case .primary: return "#A8560A"
        case .primaryHover: return "#8F4906"
        case .primaryForeground: return "#FFFFFF"
        case .success: return "#1F7A33"
        case .warning: return "#8A5A00"
        case .danger: return "#C62828"
        case .info: return "#0B5FB0"
        case .focusRing: return "#A8560A"
        case .disabled: return "#A9A49B"
        case .userBubble: return "#EFEBE4"
        }
    }

    public var darkHex: String {
        switch self {
        case .background: return "#0B0B0C"
        case .surface: return "#151517"
        case .surfaceRaised: return "#1E1E21"
        case .foreground: return "#F5F3EE"
        case .muted: return "#A3A09A"
        case .border: return "#2C2C30"
        case .primary: return "#F5A524"
        case .primaryHover: return "#FFB84D"
        case .primaryForeground: return "#1A1203"
        case .success: return "#3FB950"
        case .warning: return "#E3B341"
        case .danger: return "#F85149"
        case .info: return "#58A6FF"
        case .focusRing: return "#FFC857"
        case .disabled: return "#5A5853"
        case .userBubble: return "#232326"
        }
    }

    public var uiColor: UIColor {
        UIColor.dynamic(light: lightHex, dark: darkHex)
    }

    public var color: Color {
        Color(uiColor: uiColor)
    }
}

public enum Colors {
    public static let background = SemanticColor.background.color
    public static let surface = SemanticColor.surface.color
    public static let surfaceRaised = SemanticColor.surfaceRaised.color
    public static let foreground = SemanticColor.foreground.color
    public static let muted = SemanticColor.muted.color
    public static let border = SemanticColor.border.color
    public static let primary = SemanticColor.primary.color
    public static let primaryHover = SemanticColor.primaryHover.color
    public static let primaryForeground = SemanticColor.primaryForeground.color
    public static let success = SemanticColor.success.color
    public static let warning = SemanticColor.warning.color
    public static let danger = SemanticColor.danger.color
    public static let info = SemanticColor.info.color
    public static let focusRing = SemanticColor.focusRing.color
    public static let disabled = SemanticColor.disabled.color
    public static let userBubble = SemanticColor.userBubble.color

    public static func uiColor(for token: SemanticColor) -> UIColor {
        token.uiColor
    }
}

extension UIColor {
    static func dynamic(light: String, dark: String) -> UIColor {
        let lightColor = UIColor(hex: light)
        let darkColor = UIColor(hex: dark)
        return UIColor { traits in
            traits.userInterfaceStyle == .dark ? darkColor : lightColor
        }
    }

    convenience init(hex: String) {
        var cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanHex.hasPrefix("#") {
            cleanHex.removeFirst()
        }
        var rgbValue: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&rgbValue)
        let red = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(rgbValue & 0x0000FF) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: 1.0)
    }

    func toHexString() -> String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        if getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return String(
                format: "#%02X%02X%02X",
                Int(round(red * 255)),
                Int(round(green * 255)),
                Int(round(blue * 255))
            )
        }
        var white: CGFloat = 0
        if getWhite(&white, alpha: &alpha) {
            let val = Int(round(white * 255))
            return String(format: "#%02X%02X%02X", val, val, val)
        }
        return ""
    }
}
