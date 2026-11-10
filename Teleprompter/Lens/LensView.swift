import SwiftUI

/// Lente 600x600 igual ao T01: pergunta em muted, resposta em foreground, uma resposta por vez, sem rolagem.
struct LensView: View {
    var content: LensContent?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let content {
                Text(content.question)
                    .font(.system(size: 24)).foregroundStyle(LensTokens.muted)
                Text(MessageBubble.markdown(content.body))
                    .font(.system(size: 32)).foregroundStyle(LensTokens.foreground)
                    .lineSpacing(10)
            } else {
                Label("Pronto para ouvir", systemImage: "circle.fill")
                    .font(.system(size: 24, weight: .medium)).foregroundStyle(LensTokens.muted)
                    .tint(LensTokens.primary)
            }
        }
        .padding(LensTokens.margin)
        .frame(width: LensTokens.size, height: LensTokens.size, alignment: .leading)
        .background(LensTokens.background)
        .accessibilityElement(children: .combine)
    }
}
