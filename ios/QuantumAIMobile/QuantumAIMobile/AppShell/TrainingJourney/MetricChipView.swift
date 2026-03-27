import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct MetricChipView: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(QAITokens.Typography.caption)
                .foregroundStyle(QAITokens.Palette.textSecondary)
                .lineLimit(1)

            Text(value)
                .font(QAITokens.Typography.cardTitle)
                .foregroundStyle(QAITokens.Palette.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding(QAITokens.Spacing.m)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .background(tint)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
