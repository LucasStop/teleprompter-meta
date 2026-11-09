import SwiftUI

/// Chip para indicação de fonte ou nota (DESIGN.md 4).
public struct SourceChip: View {
    public let title: String
    public var action: (() -> Void)?

    public init(title: String, action: (() -> Void)? = nil) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        if let action {
            Button(action: action) {
                chipLabel
                    .frame(minHeight: Spacing.minTouchTarget)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Fonte: \(title)")
            .accessibilityAddTraits(.isButton)
        } else {
            chipLabel
                .accessibilityLabel("Fonte: \(title)")
        }
    }

    private var chipLabel: some View {
        Text(title)
            .font(.system(size: 12, weight: .regular, design: .monospaced))
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(Colors.muted)
            .padding(.horizontal, Spacing.s2)
            .padding(.vertical, Spacing.s1)
            .background(Colors.surface)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Colors.border, lineWidth: Borders.standard)
            )
    }
}

#Preview("SourceChip - Estados") {
    VStack(spacing: Spacing.s3) {
        SourceChip(title: "docs/ADR-0001.md")
        SourceChip(title: "qa/stack.md", action: {})
        HStack {
            SourceChip(title: "README.md")
            SourceChip(title: "qa/perguntas.md")
        }
    }
    .padding(Spacing.s4)
    .background(Colors.background)
}

#Preview("SourceChip - Escuro") {
    VStack(spacing: Spacing.s3) {
        SourceChip(title: "docs/ADR-0001.md")
        SourceChip(title: "qa/stack.md", action: {})
    }
    .padding(Spacing.s4)
    .background(Colors.background)
    .preferredColorScheme(.dark)
}
