import SwiftUI

/// Cartão com resumo métrico do último ensaio.
struct EnsaioSummaryCardView: View {
    let summary: EnsaioRunSummary

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s1) {
            Text(summary.summaryTitle)
                .font(Typography.caption)
                .foregroundStyle(Colors.muted)

            Text(summary.summaryHeadline)
                .font(Typography.h3)
                .fontWeight(.bold)
                .foregroundStyle(Colors.foreground)

            Text("Metas: WER abaixo de 15%, primeiro texto abaixo de 2 s")
                .font(Typography.caption)
                .foregroundStyle(Colors.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.s4)
        .background(Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .stroke(Colors.border, lineWidth: Borders.standard)
        )
    }
}

/// Barra de progresso de execução do ensaio.
struct EnsaioProgressBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Colors.border)
                    .frame(height: 8)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Colors.primary)
                    .frame(
                        width: max(0, min(geo.size.width, geo.size.width * fraction)),
                        height: 8
                    )
            }
        }
        .frame(height: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progresso do ensaio")
        .accessibilityValue("\(Int(fraction * 100))%")
    }
}

/// Linha de exibição de uma pergunta avaliada no ensaio com expansão de detalhes.
struct EnsaioQuestionRowView: View {
    let question: EnsaioQuestionResult
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack(alignment: .center, spacing: Spacing.s3) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(question.referenceQuestion)
                            .font(Typography.bodySm)
                            .fontWeight(.semibold)
                            .foregroundStyle(Colors.foreground)
                            .multilineTextAlignment(.leading)

                        Text(question.subtitleString)
                            .font(Typography.caption)
                            .foregroundStyle(Colors.muted)
                    }

                    Spacer(minLength: Spacing.s2)

                    StatusBadge(
                        status: question.isOk ? .ok : .erro,
                        title: question.isOk ? "ok" : "lento"
                    )
                }
                .padding(.horizontal, Spacing.s4)
                .padding(.vertical, Spacing.s3)
                .frame(minHeight: 56)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                detailsView
                    .padding(.horizontal, Spacing.s4)
                    .padding(.bottom, Spacing.s3)
                    .transition(.opacity)
            }
        }
    }

    private var detailsView: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            Divider()
                .background(Colors.border)
                .padding(.bottom, Spacing.s1)

            VStack(alignment: .leading, spacing: 2) {
                Text("TRANSCRIÇÃO")
                    .font(Typography.caption)
                    .foregroundStyle(Colors.muted)
                Text(question.transcribedText.isEmpty ? "(nenhuma fala transcrita)" : question.transcribedText)
                    .font(Typography.bodySm)
                    .foregroundStyle(Colors.foreground)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("RESPOSTA")
                    .font(Typography.caption)
                    .foregroundStyle(Colors.muted)
                Text(question.answer)
                    .font(Typography.bodySm)
                    .foregroundStyle(Colors.foreground)
            }

            latenciesView
        }
        .padding(.top, Spacing.s1)
    }

    private var latenciesView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("LATÊNCIA POR ETAPA")
                .font(Typography.caption)
                .foregroundStyle(Colors.muted)

            HStack(spacing: Spacing.s3) {
                if let sttSec = question.latency.sttFinalSeconds {
                    latencyBadge(label: "STT", seconds: sttSec)
                }
                latencyBadge(label: "Busca", seconds: question.latency.retrievalSeconds)
                if let firstTokenSec = question.latency.firstTokenSeconds {
                    latencyBadge(label: "1º token", seconds: firstTokenSec)
                }
                latencyBadge(label: "Total", seconds: question.latency.totalSeconds)
            }
        }
    }

    private func latencyBadge(label: String, seconds: Double) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(Colors.muted)
            Text(String(format: "%.2f s", seconds).replacingOccurrences(of: ".", with: ","))
                .font(Typography.code)
                .foregroundStyle(Colors.foreground)
        }
    }
}
