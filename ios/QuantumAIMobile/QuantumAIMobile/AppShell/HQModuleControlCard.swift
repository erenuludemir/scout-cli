import SwiftUI

struct HQModuleControlCard: View {
    let item: HQModuleItem
    let onAction: (HQModuleCardAction) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                HStack(alignment: .top, spacing: QAITokens.Spacing.s) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.title)
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                            .foregroundStyle(QAITokens.Palette.textPrimary)
                        Text(item.subtitle)
                            .font(QAITokens.Typography.body)
                            .foregroundStyle(QAITokens.Palette.textSecondary)
                            .lineLimit(nil)
                    }

                    Spacer(minLength: 0)

                    stateBadge(title: item.state.title, tint: item.state.tint)
                }

                HStack(spacing: QAITokens.Spacing.s) {
                    statTile(title: "Heartbeat", value: item.heartbeatText, tint: QAITokens.Palette.chipTeal)
                    statTile(title: "Uptime", value: item.uptimeText, tint: QAITokens.Palette.chipBlue)
                }

                VStack(alignment: .leading, spacing: 10) {
                    infoRow("Son hata", item.lastErrorText)
                    infoRow("Son aksiyon", item.lastActionText)
                    infoRow("Operatör", item.operatorText)
                    infoRow("Son başarı", item.lastSuccessText)
                    infoRow("Son hata zamanı", item.lastFailureText)
                    infoRow("İzleme", item.routeHint)
                }

                HStack(spacing: QAITokens.Spacing.s) {
                    bigButton(action: .start, tint: QAITokens.Palette.gold)
                    bigButton(action: .stop, tint: QAITokens.Palette.cardElevated)
                }

                HStack(spacing: QAITokens.Spacing.s) {
                    compactButton(action: .watch)
                    compactButton(action: .log)
                    compactButton(action: .fix)
                }
            }
        }
    }

    private func stateBadge(title: String, tint: Color) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(QAITokens.Palette.textPrimary)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(tint.opacity(0.22))
            .overlay(
                Capsule()
                    .stroke(tint.opacity(0.4), lineWidth: 1)
            )
            .clipShape(Capsule())
    }

    private func statTile(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(QAITokens.Typography.caption)
                .foregroundStyle(QAITokens.Palette.textSecondary)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(QAITokens.Palette.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(QAITokens.Spacing.s)
        .background(tint)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(QAITokens.Palette.textSecondary)
                .frame(width: 96, alignment: .leading)

            Text(value)
                .font(QAITokens.Typography.bodyStrong)
                .foregroundStyle(QAITokens.Palette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(nil)
        }
    }

    private func bigButton(action: HQModuleCardAction, tint: Color) -> some View {
        Button {
            onAction(action)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: action.systemImage)
                    .font(.system(size: 14, weight: .bold))
                Text(action.title)
                    .font(QAITokens.Typography.bodyStrong)
            }
            .foregroundStyle(action == .start ? QAITokens.Palette.backgroundBottom : QAITokens.Palette.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(tint)
            .clipShape(RoundedRectangle(cornerRadius: QAITokens.Radius.button, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func compactButton(action: HQModuleCardAction) -> some View {
        Button {
            onAction(action)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: action.systemImage)
                    .font(.system(size: 12, weight: .bold))
                Text(action.title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .foregroundStyle(QAITokens.Palette.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(QAITokens.Palette.cardElevated)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
