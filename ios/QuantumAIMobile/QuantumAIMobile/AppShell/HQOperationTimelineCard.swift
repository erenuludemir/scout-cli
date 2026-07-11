import SwiftUI

struct HQOperationTimelineCard: View {
    let items: [HQOperationTimelineItem]
    let filters: [HQOperationTimelineFilter]
    @Binding var selectedFilter: HQOperationTimelineFilter

    private var visibleItems: [HQOperationTimelineItem] {
        items.filter(selectedFilter.matches)
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                Label("Operation Timeline", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                    .font(QAITokens.Typography.cardTitle)
                    .foregroundStyle(QAITokens.Palette.textPrimary)

                if filters.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: QAITokens.Spacing.xs) {
                            ForEach(filters) { filter in
                                filterChip(filter)
                            }
                        }
                    }
                }

                if visibleItems.isEmpty {
                    Text("Henüz kaydedilmiş aksiyon yok. İlk operator veya backend hareketi burada belirecek.")
                        .font(QAITokens.Typography.body)
                        .foregroundStyle(QAITokens.Palette.textSecondary)
                        .lineLimit(nil)
                } else {
                    VStack(spacing: QAITokens.Spacing.s) {
                        ForEach(visibleItems) { item in
                            HStack(alignment: .top, spacing: 12) {
                                Circle()
                                    .fill(item.level.tint)
                                    .frame(width: 10, height: 10)
                                    .padding(.top, 6)

                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 8) {
                                        Text(item.timestampText)
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundStyle(QAITokens.Palette.textSecondary)

                                        Text(item.source)
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .foregroundStyle(QAITokens.Palette.textPrimary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(item.level.tint.opacity(0.18))
                                            .clipShape(Capsule())

                                        Spacer(minLength: 0)

                                        Text(item.outcome)
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .foregroundStyle(item.level.tint)
                                    }

                                    Text("\(item.module) • \(item.title)")
                                        .font(QAITokens.Typography.bodyStrong)
                                        .foregroundStyle(QAITokens.Palette.textPrimary)

                                    Text(item.detail)
                                        .font(QAITokens.Typography.body)
                                        .foregroundStyle(QAITokens.Palette.textSecondary)
                                        .lineLimit(nil)
                                }
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

    private func filterChip(_ filter: HQOperationTimelineFilter) -> some View {
        let isSelected = selectedFilter == filter
        let count = items.filter(filter.matches).count
        return Button {
            selectedFilter = filter
        } label: {
            Text("\(filter.title) \(count)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(
                    isSelected ? QAITokens.Palette.backgroundBottom : QAITokens.Palette.textPrimary
                )
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(isSelected ? QAITokens.Palette.gold : QAITokens.Palette.cardElevated)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
