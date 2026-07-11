import SwiftUI

struct HQRuntimeOperationsCard: View {
    let lanes: [HQRuntimeTrendLane]
    let topics: [HQRuntimeTopicItem]
    let replayAction: () -> Void
    let logsAction: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                header

                if !lanes.isEmpty {
                    LazyVGrid(columns: columns, spacing: QAITokens.Spacing.s) {
                        ForEach(lanes) { lane in
                            NavigationLink {
                                RuntimeTrendDetailView(lane: lane)
                            } label: {
                                HQRuntimeTrendTile(lane: lane)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !topics.isEmpty {
                    VStack(alignment: .leading, spacing: QAITokens.Spacing.s) {
                        Text("Topic Activity")
                            .font(QAITokens.Typography.caption)
                            .foregroundStyle(QAITokens.Palette.textSecondary)

                        ForEach(topics) { topic in
                            HQRuntimeTopicRow(item: topic)
                        }
                    }
                }

                HStack(spacing: QAITokens.Spacing.s) {
                    actionButton(title: "Replay DLQ", icon: "arrow.clockwise.circle.fill", tint: QAITokens.Palette.gold, action: replayAction)
                    actionButton(title: "Open Logs", icon: "list.bullet.rectangle.portrait", tint: QAITokens.Palette.cardElevated, action: logsAction)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Runtime Pulse", systemImage: "waveform.path.ecg.rectangle")
                .font(QAITokens.Typography.cardTitle)
                .foregroundStyle(QAITokens.Palette.textPrimary)
            Text("Trend, replay ve topic aktivitesi recovery ekranına girmeden görünür olmalı.")
                .font(QAITokens.Typography.body)
                .foregroundStyle(QAITokens.Palette.textSecondary)
                .lineLimit(nil)
        }
    }

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: QAITokens.Spacing.s), GridItem(.flexible(), spacing: QAITokens.Spacing.s)]
    }

    private func actionButton(title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundStyle(QAITokens.Palette.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(tint)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct HQRuntimeTrendTile: View {
    let lane: HQRuntimeTrendLane

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(lane.title)
                .font(QAITokens.Typography.caption)
                .foregroundStyle(QAITokens.Palette.textSecondary)
            Text(lane.value)
                .font(.system(size: 20, weight: .black, design: .monospaced))
                .foregroundStyle(QAITokens.Palette.textPrimary)
            Text(lane.detail)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(QAITokens.Palette.textSecondary)
            HQMiniSparkline(values: lane.points)
                .stroke(lane.tint, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .frame(height: 26)
        }
        .padding(QAITokens.Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(lane.tint.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct HQRuntimeTopicRow: View {
    let item: HQRuntimeTopicItem

    var body: some View {
        HStack(alignment: .center, spacing: QAITokens.Spacing.s) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.topic)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(QAITokens.Palette.textPrimary)
                Text("last \(item.lastSeenText)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(QAITokens.Palette.textSecondary)
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                metricChip(title: "S", value: item.sentText)
                metricChip(title: "R", value: item.replayText)
                metricChip(title: "D", value: item.deadLetterText)
            }
        }
        .padding(QAITokens.Spacing.s)
        .background(item.tint)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func metricChip(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(QAITokens.Palette.textSecondary)
            Text(value)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(QAITokens.Palette.textPrimary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.06))
        .clipShape(Capsule())
    }
}

private struct HQMiniSparkline: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        guard values.count > 1 else { return Path() }
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 0
        let span = max(maxValue - minValue, 1)

        return Path { path in
            for (index, value) in values.enumerated() {
                let x = rect.minX + (rect.width * CGFloat(index) / CGFloat(values.count - 1))
                let normalized = (value - minValue) / span
                let y = rect.maxY - (rect.height * CGFloat(normalized))
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
    }
}
