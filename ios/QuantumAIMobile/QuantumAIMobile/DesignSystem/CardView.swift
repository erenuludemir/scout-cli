import SwiftUI

public struct CardView<Content: View>: View {
    @ViewBuilder let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading) {
            content
        }
        .padding(QAITheme.compactCardPadding)
        .background(
            ZStack {
                QAITheme.cardGradient
                LinearGradient(
                    colors: [QAITheme.panelBlue.opacity(0.18), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: QAITheme.compactCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: QAITheme.compactCornerRadius, style: .continuous)
                .stroke(QAITheme.border, lineWidth: 1)
                .allowsHitTesting(false)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 10)
    }
}
