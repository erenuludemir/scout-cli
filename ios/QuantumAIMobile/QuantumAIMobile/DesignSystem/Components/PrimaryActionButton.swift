import SwiftUI

public struct PrimaryActionButton: View {
    public enum Style {
        case primary
        case secondary
    }

    private let title: String
    private let style: Style
    private let action: () -> Void

    public init(title: String, style: Style = .primary, action: @escaping () -> Void) {
        self.title = title
        self.style = style
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(QAITokens.Typography.bodyStrong)
                .foregroundStyle(style == .primary ? QAITokens.Palette.backgroundBottom : QAITokens.Palette.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(style == .primary ? QAITokens.Palette.gold : QAITokens.Palette.cardElevated)
                .clipShape(RoundedRectangle(cornerRadius: QAITokens.Radius.button, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
