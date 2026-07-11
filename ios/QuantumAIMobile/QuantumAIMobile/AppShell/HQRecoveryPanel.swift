import SwiftUI

struct HQRecoveryPanel: View {
    let actions: [HQRecoveryActionKind]
    let commandState: HQCommandState
    let lastCommandText: String
    let onAction: (HQRecoveryActionKind) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                Label("Incident & Recovery Panel", systemImage: "cross.case.fill")
                    .font(QAITokens.Typography.cardTitle)
                    .foregroundStyle(QAITokens.Palette.textPrimary)

                Text("Self-heal, rollback, queue flush, telemetry export ve seal komutları kontrollü olarak bu panelden yürütülür.")
                    .font(QAITokens.Typography.body)
                    .foregroundStyle(QAITokens.Palette.textSecondary)
                    .lineLimit(nil)

                HStack(spacing: QAITokens.Spacing.s) {
                    stateStrip(title: "Komut", value: commandState.title)
                    stateStrip(title: "Koruma", value: "2-Aşamalı")
                    stateStrip(title: "Son", value: lastCommandText)
                }

                LazyVGrid(columns: columns, spacing: QAITokens.Spacing.s) {
                    ForEach(actions) { action in
                        Button {
                            onAction(action)
                        } label: {
                            VStack(alignment: .leading, spacing: 12) {
                                Image(systemName: action.systemImage)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(iconTint(for: action))

                                Text(action.title)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(QAITokens.Palette.textPrimary)
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)

                                Spacer(minLength: 0)

                                Text(label(for: action))
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(QAITokens.Palette.textSecondary)
                            }
                            .padding(QAITokens.Spacing.m)
                            .frame(maxWidth: .infinity, minHeight: 138, alignment: .topLeading)
                            .background(backgroundTint(for: action))
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Tehlikeli komutlar")
                        .font(QAITokens.Typography.bodyStrong)
                        .foregroundStyle(QAITokens.Palette.textPrimary)
                    Text("Rollback, Queue Flush ve Seal System işlemleri confirm sheet ve ikinci doğrulama metni olmadan yürütülmez.")
                        .font(QAITokens.Typography.caption)
                        .foregroundStyle(QAITokens.Palette.textSecondary)
                        .lineLimit(nil)
                }
                .padding(QAITokens.Spacing.s)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: QAITokens.Spacing.s),
            GridItem(.flexible(), spacing: QAITokens.Spacing.s)
        ]
    }

    private func stateStrip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(QAITokens.Palette.textSecondary)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(QAITokens.Palette.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func backgroundTint(for action: HQRecoveryActionKind) -> Color {
        if action.isDangerous { return Color.red.opacity(0.18) }
        if action.isPrimary { return QAITokens.Palette.chipTeal }
        return QAITokens.Palette.cardElevated
    }

    private func iconTint(for action: HQRecoveryActionKind) -> Color {
        if action.isDangerous { return QAITokens.Palette.warning }
        if action.isPrimary { return QAITokens.Palette.teal }
        return QAITokens.Palette.gold
    }

    private func label(for action: HQRecoveryActionKind) -> String {
        if action.isDangerous { return "PROTECTED" }
        if action.isPrimary { return "PRIMARY" }
        return "ACTION"
    }
}
