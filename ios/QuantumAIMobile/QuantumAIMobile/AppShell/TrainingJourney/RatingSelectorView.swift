import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct RatingSelectorView: View {
    @Binding var selectedRating: Int
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: QAITokens.Spacing.s) {
            Text("Faydali oldu mu?")
                .font(QAITokens.Typography.bodyStrong)
                .foregroundStyle(QAITokens.Palette.textPrimary)

            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { score in
                    Button {
                        selectedRating = score
                        onSelect(score)
                    } label: {
                        Text("\(score)")
                            .font(QAITokens.Typography.bodyStrong)
                            .foregroundStyle(selectedRating == score ? QAITokens.Palette.backgroundBottom : QAITokens.Palette.textPrimary)
                            .frame(width: 44, height: 44)
                            .background(selectedRating == score ? QAITokens.Palette.gold : QAITokens.Palette.cardElevated)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Puan \(score)")
                }
            }
        }
    }
}
