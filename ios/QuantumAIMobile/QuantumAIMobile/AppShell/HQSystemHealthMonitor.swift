import SwiftUI

struct HQSystemHealthMonitor: View {
    let items: [HQQuickMonitor]
    let tags: [String]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                Label("System Health Monitor", systemImage: "waveform.path.ecg")
                    .font(QAITokens.Typography.cardTitle)
                    .foregroundStyle(QAITokens.Palette.textPrimary)

                Text("CPU, RAM, queue backlog, oracle sync ve runtime pulse tek satır health yüzeyinde özetlenir.")
                    .font(QAITokens.Typography.body)
                    .foregroundStyle(QAITokens.Palette.textSecondary)
                    .lineLimit(nil)

                LazyVGrid(columns: columns, spacing: QAITokens.Spacing.s) {
                    ForEach(items) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.title)
                                .font(QAITokens.Typography.caption)
                                .foregroundStyle(QAITokens.Palette.textSecondary)
                            Text(item.value)
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundStyle(QAITokens.Palette.textPrimary)
                            if let detail = item.detail {
                                Text(detail)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(QAITokens.Palette.textSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(QAITokens.Spacing.s)
                        .background(item.tint)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }

                FlexibleTagWrap(tags: tags)
            }
        }
    }

    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: QAITokens.Spacing.s),
            GridItem(.flexible(), spacing: QAITokens.Spacing.s)
        ]
    }
}

private struct FlexibleTagWrap: View {
    let tags: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: QAITokens.Spacing.s) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: QAITokens.Spacing.s) {
                    ForEach(row, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(QAITokens.Palette.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.05))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private var rows: [[String]] {
        stride(from: 0, to: tags.count, by: 3).map { start in
            Array(tags[start..<min(start + 3, tags.count)])
        }
    }
}
