import SwiftUI

/// Placeholder para a aba Chat (T02 Chat da sessão).
public struct ChatPlaceholderView: View {
    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.s4) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 48))
                    .foregroundStyle(Colors.primary)

                Text("Chat da sessão")
                    .font(Typography.h1)
                    .foregroundStyle(Colors.foreground)

                Text("Converse com o seu material importado ou ative a escuta contínua durante a banca.")
                    .font(Typography.body)
                    .foregroundStyle(Colors.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.s5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Colors.background)
            .navigationTitle("Chat")
        }
    }
}

#Preview {
    ChatPlaceholderView()
}
