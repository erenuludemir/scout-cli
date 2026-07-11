import SwiftUI

struct HQEventStreamPanel: View {
    let events: [HQEventItem]
    let lastCommandText: String
    let exportAction: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                HStack {
                    Label("Audit & Event Stream", systemImage: "list.bullet.rectangle.portrait")
                        .font(QAITokens.Typography.cardTitle)
                        .foregroundStyle(QAITokens.Palette.textPrimary)

                    Spacer()

                    Button(action: exportAction) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export")
                        }
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(QAITokens.Palette.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(QAITokens.Palette.cardElevated)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Text("Son komut: \(lastCommandText)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(QAITokens.Palette.textSecondary)

                VStack(spacing: QAITokens.Spacing.s) {
                    ForEach(events) { event in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.timestamp)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(QAITokens.Palette.textSecondary)
                                Text(event.module)
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(event.level.tint)
                            }
                            .frame(width: 84, alignment: .leading)

                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text(event.level.title)
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundStyle(event.level.tint)
                                    Text(event.outcome)
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundStyle(QAITokens.Palette.textSecondary)
                                }

                                Text(event.message)
                                    .font(QAITokens.Typography.bodyStrong)
                                    .foregroundStyle(QAITokens.Palette.textPrimary)
                                    .lineLimit(nil)
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(QAITokens.Spacing.s)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
            }
        }
    }
}
