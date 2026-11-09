import SwiftUI

/// Placeholder para a aba Ajustes (T03 Configurações).
public struct AjustesPlaceholderView: View {
    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.s4) {
                Image(systemName: "gearshape")
                    .font(.system(size: 48))
                    .foregroundStyle(Colors.primary)

                Text("Ajustes")
                    .font(Typography.h1)
                    .foregroundStyle(Colors.foreground)

                Text("Configure chaves de API, formato da resposta na lente, limiares de silêncio e estado dos óculos.")
                    .font(Typography.body)
                    .foregroundStyle(Colors.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.s5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Colors.background)
            .navigationTitle("Ajustes")
        }
    }
}

#Preview {
    AjustesPlaceholderView()
}
