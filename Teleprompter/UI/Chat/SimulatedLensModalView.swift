import SwiftUI

/// Painel modal de exibição da lente simulada (T01) a partir da aba Chat.
struct SimulatedLensModalView: View {
    @Environment(\.dismiss) private var dismiss
    var content: LensContent?

    init(content: LensContent? = nil) {
        self.content = content
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                GeometryReader { geo in
                    let availableWidth = max(geo.size.width - Spacing.s4 * 2, 280)
                    let scale = min(1.0, availableWidth / LensTokens.size)

                    VStack {
                        Spacer()
                        LensView(content: content)
                            .scaleEffect(scale)
                            .frame(
                                width: LensTokens.size * scale,
                                height: LensTokens.size * scale
                            )
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.lg)
                                    .stroke(Colors.border, lineWidth: Borders.standard)
                            )
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Lente simulada")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") {
                        dismiss()
                    }
                    .font(Typography.bodySm)
                    .fontWeight(.semibold)
                    .foregroundStyle(Colors.primary)
                    .frame(minHeight: Spacing.minTouchTarget)
                    .accessibilityLabel("Fechar lente simulada")
                }
            }
        }
    }
}
