import SwiftUI
@available(iOS 17.0, macOS 14.0, *)

public struct TagView: View {
    let text: String

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(QAITheme.captionFont)
            .padding(.horizontal, QAITheme.compactChipHorizontalPadding)
            .padding(.vertical, QAITheme.compactChipVerticalPadding)
            .background(QAITheme.warning.opacity(0.2))
            .clipShape(Capsule())
            .foregroundColor(.white)
    }
}
