import SwiftUI
@available(iOS 17.0, macOS 14.0, *)

public struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    public init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(QAITheme.buttonFont)
                .foregroundStyle(QAITheme.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, QAITheme.compactButtonVerticalPadding)
                .background(
                    LinearGradient(
                        colors: [QAITheme.accent, QAITheme.accent.opacity(0.84)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: QAITheme.compactInnerCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
