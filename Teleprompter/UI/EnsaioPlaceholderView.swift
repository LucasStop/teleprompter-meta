import SwiftUI

/// Placeholder para a aba Ensaio (T05 Ensaio com perguntas gravadas).
public struct EnsaioPlaceholderView: View {
    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.s4) {
                Image(systemName: "waveform")
                    .font(.system(size: 48))
                    .foregroundStyle(Colors.primary)

                Text("Ensaio com áudio")
                    .font(Typography.h1)
                    .foregroundStyle(Colors.foreground)

                Text("Simule perguntas gravadas da banca e valide as respostas geradas na lente e no iPhone.")
                    .font(Typography.body)
                    .foregroundStyle(Colors.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.s5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Colors.background)
            .navigationTitle("Ensaio")
        }
    }
}

#Preview {
    EnsaioPlaceholderView()
}
