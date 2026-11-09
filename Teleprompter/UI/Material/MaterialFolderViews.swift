import SwiftUI

// MARK: - Telas de Importação de Pasta (DESIGN.md / t04-importacao.html)

struct FolderConfirmationContentView: View {
    let confirmation: MaterialScreenState.FolderConfirmationState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s4) {
                // Sec: Pasta escolhida
                VStack(alignment: .leading, spacing: Spacing.s2) {
                    Text("Pasta escolhida")
                        .font(Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Colors.muted)
                        .textCase(.uppercase)

                    VStack(alignment: .leading, spacing: Spacing.s1) {
                        Text(confirmation.folderName)
                            .font(Typography.body)
                            .fontWeight(.bold)
                            .foregroundStyle(Colors.foreground)

                        let validSuffix = confirmation.validFilesCount == 1 ? "arquivo válido" : "arquivos válidos"
                        Text("\(formatNumber(confirmation.validFilesCount)) \(validSuffix)")
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

                // Sec: O que será importado
                VStack(alignment: .leading, spacing: Spacing.s2) {
                    Text("O que será importado")
                        .font(Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Colors.muted)
                        .textCase(.uppercase)

                    VStack(spacing: 0) {
                        if confirmation.qaCount > 0 {
                            let qaCountSuffix = confirmation.qaCount == 1 ? "arquivo" : "arquivos"
                            MaterialItemRow(
                                title: "Notas de Q&A",
                                subtitle: "qa/",
                                value: "\(formatNumber(confirmation.qaCount)) \(qaCountSuffix)"
                            )
                        }
                        if confirmation.documentCount > 0 {
                            if confirmation.qaCount > 0 {
                                Divider().background(Colors.border)
                            }
                            let docSuffix = confirmation.documentCount == 1 ? "arquivo" : "arquivos"
                            MaterialItemRow(
                                title: "Documentos",
                                subtitle: "README, docs/, ADRs",
                                value: "\(formatNumber(confirmation.documentCount)) \(docSuffix)"
                            )
                        }
                        if confirmation.codeCount > 0 {
                            if confirmation.qaCount > 0 || confirmation.documentCount > 0 {
                                Divider().background(Colors.border)
                            }
                            let codeSuffix = confirmation.codeCount == 1 ? "arquivo" : "arquivos"
                            MaterialItemRow(
                                title: "Código",
                                subtitle: "swift, ts, php",
                                value: "\(formatNumber(confirmation.codeCount)) \(codeSuffix)"
                            )
                        }
                    }
                    .background(Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .stroke(Colors.border, lineWidth: Borders.standard)
                    )
                }

                // Sec: Ignorados
                if !confirmation.ignoredGroups.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.s2) {
                        Text("Ignorados")
                            .font(Typography.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Colors.muted)
                            .textCase(.uppercase)

                        VStack(spacing: 0) {
                            ForEach(Array(confirmation.ignoredGroups.enumerated()), id: \.element.reason) { idx, group in
                                if idx > 0 {
                                    Divider().background(Colors.border)
                                }
                                let groupSuffix = group.count == 1 ? "arquivo" : "arquivos"
                                MaterialItemRow(
                                    title: group.title,
                                    subtitle: group.subtitle,
                                    value: "\(formatNumber(group.count)) \(groupSuffix)"
                                )
                            }
                        }
                        .background(Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .stroke(Colors.border, lineWidth: Borders.standard)
                        )
                    }
                }
            }
            .padding(.horizontal, Spacing.s4)
            .padding(.top, Spacing.s2)
        }
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

struct FolderProgressContentView: View {
    let progress: MaterialScreenState.FolderProgressState

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            VStack(alignment: .leading, spacing: Spacing.s2) {
                Text(progress.folderName)
                    .font(Typography.body)
                    .fontWeight(.bold)
                    .foregroundStyle(Colors.foreground)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Colors.border)
                            .frame(height: 6)

                        Capsule()
                            .fill(Colors.primary)
                            .frame(
                                width: max(6, geo.size.width * CGFloat(max(0.05, min(1.0, progress.progress)))),
                                height: 6
                            )
                    }
                }
                .frame(height: 6)
                .accessibilityLabel("Progresso da indexação da pasta")
                .accessibilityValue("\(Int(progress.progress * 100)) por cento")

                Text("\(formatNumber(progress.current)) de \(formatNumber(progress.total)) arquivos")
                    .font(Typography.caption)
                    .foregroundStyle(Colors.muted)

                Text(progress.currentFileName)
                    .font(Typography.caption)
                    .foregroundStyle(Colors.muted)
                    .lineLimit(1)
            }
            .padding(Spacing.s4)
            .background(Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .stroke(Colors.border, lineWidth: Borders.standard)
            )
            .padding(.horizontal, Spacing.s4)

            Spacer()
        }
        .padding(.top, Spacing.s2)
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

struct FolderConcluidoContentView: View {
    let sources: [MaterialSource]
    let banner: MaterialScreenState.FolderResultBanner?
    let onRemoveSource: (MaterialSource) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                Text("Fontes")
                    .font(Typography.h2)
                    .foregroundStyle(Colors.foreground)
                    .padding(.horizontal, Spacing.s4)

                VStack(spacing: 0) {
                    ForEach(Array(sources.enumerated()), id: \.element.id) { index, source in
                        if index > 0 {
                            Divider()
                                .background(Colors.border)
                        }
                        MaterialSourceRow(source: source) {
                            onRemoveSource(source)
                        }
                    }
                }
                .background(Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(Colors.border, lineWidth: Borders.standard)
                )
                .padding(.horizontal, Spacing.s4)

                if let banner {
                    HStack(alignment: .top, spacing: Spacing.s2) {
                        Text("\(formatNumber(banner.ignoredCount)) arquivos ignorados.")
                            .fontWeight(.bold)
                            .foregroundStyle(Colors.danger)
                            + Text(" " + banner.message)
                            .foregroundStyle(Colors.foreground)
                    }
                    .font(Typography.bodySm)
                    .padding(Spacing.s3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .stroke(Colors.danger, lineWidth: Borders.standard)
                    )
                    .padding(.horizontal, Spacing.s4)
                    .padding(.top, Spacing.s2)
                }
            }
        }
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}
