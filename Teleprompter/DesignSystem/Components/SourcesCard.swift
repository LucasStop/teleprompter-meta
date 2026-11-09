import SwiftUI

/// Bloco recolhível de fontes do material (DESIGN.md 4 e protótipo T02).
public struct SourcesCard: View {
    public let sources: [String]
    @State private var isExpanded: Bool

    public init(sources: [String], initiallyExpanded: Bool = false) {
        self.sources = sources
        self._isExpanded = State(initialValue: initiallyExpanded)
    }

    public var body: some View {
        if !sources.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.s2) {
                Button(
                    action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    },
                    label: {
                        HStack(spacing: Spacing.s1) {
                            Text("\(sources.count)")
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Colors.primary)

                            Text(sources.count == 1 ? "fonte do seu material" : "fontes do seu material")
                                .font(Typography.bodySm)
                                .foregroundStyle(Colors.muted)

                            Spacer()

                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Colors.muted)
                        }
                        .frame(minHeight: 28)
                        .contentShape(Rectangle())
                    }
                )
                .buttonStyle(.plain)
                .accessibilityLabel(isExpanded ? "Ocultar fontes" : "Mostrar fontes")
                .accessibilityValue("\(sources.count) \(sources.count == 1 ? "fonte" : "fontes")")

                if isExpanded {
                    VStack(alignment: .leading, spacing: Spacing.s1) {
                        ForEach(Array(sources.enumerated()), id: \.offset) { index, source in
                            HStack(alignment: .top, spacing: Spacing.s2) {
                                Text("\(index + 1)")
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(Colors.primary)
                                    .frame(minWidth: 14, alignment: .leading)

                                Text(source)
                                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                                    .foregroundStyle(Colors.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                    }
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, Spacing.s3)
            .padding(.vertical, Spacing.s2)
            .background(Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .stroke(Colors.border, lineWidth: Borders.standard)
            )
        }
    }
}

#Preview("SourcesCard - Fechado") {
    VStack(spacing: Spacing.s3) {
        SourcesCard(sources: ["README.md"])
        SourcesCard(sources: ["qa/stack.md", "docs/adr/0001-swift-nativo-com-dat-sdk.md"])
    }
    .padding(Spacing.s4)
    .background(Colors.background)
}

#Preview("SourcesCard - Aberto") {
    VStack(spacing: Spacing.s3) {
        SourcesCard(sources: ["qa/stack.md", "docs/adr/0001-swift-nativo-com-dat-sdk.md"], initiallyExpanded: true)
    }
    .padding(Spacing.s4)
    .background(Colors.background)
    .preferredColorScheme(.dark)
}
