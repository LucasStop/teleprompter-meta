import SwiftUI

/// Opções de provedores suportados na tela de Ajustes.
enum LLMProviderOption: String, CaseIterable, Sendable, Identifiable {
    case openai
    case anthropic

    var id: String { rawValue }
    var title: String {
        switch self {
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        }
    }
}

struct SettingsSliderRow: View {
    let title: String
    let subtitle: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let isSeconds: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.s1) {
                    Text(title).font(Typography.bodySm).fontWeight(.semibold).foregroundStyle(Colors.foreground)
                    Text(subtitle).font(Typography.caption).foregroundStyle(Colors.muted)
                }
                Spacer()
                Text(formattedValue).font(Typography.bodySm).foregroundStyle(Colors.muted)
            }
            Slider(value: $value, in: range, step: step).tint(Colors.primary).accessibilityLabel(title)
            if !isSeconds {
                HStack {
                    Text("Mais respostas").font(Typography.caption).foregroundStyle(Colors.muted)
                    Spacer()
                    Text(formattedValue).font(Typography.caption).fontWeight(.semibold).foregroundStyle(Colors.foreground)
                    Spacer()
                    Text("Mais rigor").font(Typography.caption).foregroundStyle(Colors.muted)
                }
            }
        }
        .padding(Spacing.s4)
    }

    private var formattedValue: String {
        let pattern = isSeconds ? "%.1f s" : "%.2f"
        return String(format: pattern, value).replacingOccurrences(of: ".", with: ",")
    }
}

struct SegmentedChoiceRow<Item: Hashable & Sendable>: View {
    let items: [Item]
    let titleFor: KeyPath<Item, String>
    @Binding var selection: Item

    var body: some View {
        HStack(spacing: Spacing.s1) {
            ForEach(items, id: \.self) { item in
                let isSelected = selection == item
                let label = item[keyPath: titleFor]
                Button {
                    selection = item
                } label: {
                    Text(label)
                        .font(Typography.bodySm)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundStyle(isSelected ? Colors.primaryForeground : Colors.foreground)
                        .frame(maxWidth: .infinity, minHeight: Spacing.minTouchTarget)
                        .background(isSelected ? Colors.primary : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(label)
                .accessibilityIdentifier("choice-\(label)")
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(Spacing.s1)
        .background(Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .stroke(Colors.border, lineWidth: Borders.standard)
        )
    }
}
