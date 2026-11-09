import SwiftUI

/// Placeholder para a aba Material (T04 Importação de material).
public struct MaterialPlaceholderView: View {
    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.s4) {
                Image(systemName: "doc.text")
                    .font(.system(size: 48))
                    .foregroundStyle(Colors.primary)

                Text("Material do projeto")
                    .font(Typography.h1)
                    .foregroundStyle(Colors.foreground)

                Text("Importe notas em Markdown, PRD, arquitetura e notas de Q&A para alimentar as respostas.")
                    .font(Typography.body)
                    .foregroundStyle(Colors.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.s5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Colors.background)
            .navigationTitle("Material")
        }
    }
}

#Preview {
    MaterialPlaceholderView()
}
