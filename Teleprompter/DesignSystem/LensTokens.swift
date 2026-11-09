import SwiftUI

/// Tokens da lente (DESIGN.md 3.1/3.2): sempre escura, só foreground, muted e primary.
enum LensTokens {
    static let background = Color.black
    static let foreground = Color(red: 0.961, green: 0.953, blue: 0.933) // #F5F3EE
    static let muted = Color(red: 0.639, green: 0.627, blue: 0.604) // #A3A09A
    static let primary = Color(red: 0.961, green: 0.647, blue: 0.141) // #F5A524
    static let size: CGFloat = 600
    static let margin: CGFloat = 32
}
