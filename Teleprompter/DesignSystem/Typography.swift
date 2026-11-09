import SwiftUI

// swiftlint:disable identifier_name
/// Tokens de tipografia (DESIGN.md 3.2) compatíveis com Dynamic Type no iPhone.
public enum Typography {
    public static let display = Font.system(.largeTitle, design: .default, weight: .bold)
    public static let h1 = Font.system(.title, design: .default, weight: .bold)
    public static let h2 = Font.system(.title2, design: .default, weight: .semibold)
    public static let h3 = Font.system(.headline, design: .default, weight: .semibold)
    public static let body = Font.system(.body, design: .default, weight: .regular)
    public static let bodySm = Font.system(.subheadline, design: .default, weight: .regular)
    public static let caption = Font.system(.caption, design: .default, weight: .regular)
    public static let code = Font.system(.subheadline, design: .monospaced, weight: .regular)

    public static let displaySize: CGFloat = 34
    public static let displayLineHeight: CGFloat = 41

    public static let h1Size: CGFloat = 28
    public static let h1LineHeight: CGFloat = 34

    public static let h2Size: CGFloat = 22
    public static let h2LineHeight: CGFloat = 28

    public static let h3Size: CGFloat = 17
    public static let h3LineHeight: CGFloat = 22

    public static let bodySize: CGFloat = 17
    public static let bodyLineHeight: CGFloat = 24

    public static let bodySmSize: CGFloat = 15
    public static let bodySmLineHeight: CGFloat = 20

    public static let captionSize: CGFloat = 12
    public static let captionLineHeight: CGFloat = 16

    public static let codeSize: CGFloat = 15
    public static let codeLineHeight: CGFloat = 20
}
// swiftlint:enable identifier_name
