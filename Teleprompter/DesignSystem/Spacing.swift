import Foundation

// swiftlint:disable identifier_name
/// Tokens de espaçamento e layout (DESIGN.md 3.3).
public enum Spacing {
    public static let s1: CGFloat = 4
    public static let s2: CGFloat = 8
    public static let s3: CGFloat = 12
    public static let s4: CGFloat = 16
    public static let s5: CGFloat = 24
    public static let s6: CGFloat = 32
    public static let s7: CGFloat = 48
    public static let s8: CGFloat = 64

    public static let scale: [CGFloat] = [4, 8, 12, 16, 24, 32, 48, 64]
    public static let gutter: CGFloat = 16
    public static let minTouchTarget: CGFloat = 44
}

/// Raios de arredondamento (DESIGN.md 3.4).
public enum CornerRadius {
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let full: CGFloat = 999
}
// swiftlint:enable identifier_name

/// Espessuras de borda padrão (DESIGN.md 3.4).
public enum Borders {
    public static let standard: CGFloat = 1
}
