import SwiftUI

struct HQGlobalControlCard: View {
    let globalState: HQGlobalState
    let buildText: String
    let modeText: String
    let lastSyncText: String
    let commandState: HQCommandState
    let lastCommandText: String
    let lastSuccessText: String
    let lastFailureText: String
    let recoveryAction: () -> Void
    let onAction: (HQGlobalAction) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                HStack(alignment: .top, spacing: QAITokens.Spacing.m) {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(QAITokens.Palette.chipTeal)
                        .frame(width: 72, height: 72)
                        .overlay {
                            Image(systemName: "dot.radiowaves.up.forward")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundStyle(QAITokens.Palette.textPrimary)
                        }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("BURSA HQ ADMIN")
                            .font(.system(size: 21, weight: .black, design: .monospaced))
                            .foregroundStyle(QAITokens.Palette.textPrimary)
                        Text(buildText)
                            .font(QAITokens.Typography.bodyStrong)
                            .foregroundStyle(QAITokens.Palette.textSecondary)
                        Text(modeText)
                            .font(QAITokens.Typography.caption)
                            .foregroundStyle(QAITokens.Palette.textSecondary)
                            .lineLimit(nil)
                    }

                    Spacer(minLength: 0)

                    stateBadge(title: globalState.title, tint: globalState.tint)
                }

                Text("HQ Admin artık sadece dashboard değil; global operasyon, recovery, güvenlik kilidi ve canlı komut yürütme yüzeyini tek panelde toplar.")
                    .font(QAITokens.Typography.body)
                    .foregroundStyle(QAITokens.Palette.textPrimary)
                    .lineLimit(nil)

                HStack(spacing: QAITokens.Spacing.s) {
                    infoChip("State \(commandState.title)")
                    infoChip(lastSyncText)
                    infoChip("Last \(lastCommandText)")
                }

                HStack(spacing: QAITokens.Spacing.s) {
                    primaryButton(title: HQGlobalAction.activate.title, icon: HQGlobalAction.activate.systemImage, tint: QAITokens.Palette.gold) {
                        onAction(.activate)
                    }
                    primaryButton(title: HQGlobalAction.stop.title, icon: HQGlobalAction.stop.systemImage, tint: QAITokens.Palette.cardElevated) {
                        onAction(.stop)
                    }
                }

                primaryButton(title: "Recovery", icon: "bandage.fill", tint: QAITokens.Palette.chipTeal, action: recoveryAction)

                LazyVGrid(columns: columns, spacing: QAITokens.Spacing.s) {
                    ForEach([HQGlobalAction.softRestart, .forceRestart, .safeMode, .dryRun], id: \.id) { action in
                        primaryButton(
                            title: action.title,
                            icon: action.systemImage,
                            tint: action == .forceRestart ? QAITokens.Palette.warning : QAITokens.Palette.cardElevated
                        ) {
                            onAction(action)
                        }
                    }
                }

                primaryButton(
                    title: HQGlobalAction.emergencyStop.title,
                    icon: HQGlobalAction.emergencyStop.systemImage,
                    tint: Color.red.opacity(0.78)
                ) {
                    onAction(.emergencyStop)
                }

                HStack(spacing: QAITokens.Spacing.s) {
                    footerStat(title: "Last Success", value: lastSuccessText)
                    footerStat(title: "Last Failure", value: lastFailureText)
                    footerStat(title: "Operator", value: "hq.admin")
                }
            }
        }
    }

    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: QAITokens.Spacing.s),
            GridItem(.flexible(), spacing: QAITokens.Spacing.s)
        ]
    }

    private func stateBadge(title: String, tint: Color) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundStyle(QAITokens.Palette.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(tint.opacity(0.22))
            .overlay(
                Capsule()
                    .stroke(tint.opacity(0.48), lineWidth: 1)
            )
            .clipShape(Capsule())
    }

    private func infoChip(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(QAITokens.Palette.textSecondary)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.05))
            .clipShape(Capsule())
    }

    private func footerStat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(QAITokens.Palette.textSecondary)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(QAITokens.Palette.textPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(QAITokens.Spacing.s)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func primaryButton(
        title: String,
        icon: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                Text(title)
                    .font(QAITokens.Typography.bodyStrong)
                    .lineLimit(1)
            }
            .foregroundStyle(title == HQGlobalAction.activate.title ? QAITokens.Palette.backgroundBottom : QAITokens.Palette.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(tint)
            .clipShape(RoundedRectangle(cornerRadius: QAITokens.Radius.button, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
