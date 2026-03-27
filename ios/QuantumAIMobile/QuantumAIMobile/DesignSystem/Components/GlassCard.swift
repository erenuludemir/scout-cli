import SwiftUI

public struct GlassCard<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: QAITokens.Radius.card, style: .continuous)

        content
            .padding(QAITokens.Layout.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: shape)
            .background(QAITokens.Palette.card, in: shape)
            .overlay(
                shape.stroke(QAITokens.Palette.stroke, lineWidth: 1)
            )
    }
}
