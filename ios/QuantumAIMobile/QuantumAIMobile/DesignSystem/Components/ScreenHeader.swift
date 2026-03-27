import SwiftUI

public struct ScreenHeader: View {
    private let title: String
    private let showsBackButton: Bool
    private let onBack: (() -> Void)?

    public init(title: String, showsBackButton: Bool = false, onBack: (() -> Void)? = nil) {
        self.title = title
        self.showsBackButton = showsBackButton
        self.onBack = onBack
    }

    public var body: some View {
        ZStack {
            Text(title)
                .font(QAITokens.Typography.screenTitle)
                .foregroundStyle(QAITokens.Palette.textPrimary)
                .lineLimit(nil)
                .multilineTextAlignment(.center)

            HStack {
                if showsBackButton {
                    Button(action: { onBack?() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(QAITokens.Palette.textPrimary)
                            .frame(width: 44, height: 44)
                            .background(QAITokens.Palette.cardElevated)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Geri")
                } else {
                    Color.clear
                        .frame(width: 44, height: 44)
                }

                Spacer()

                Color.clear
                    .frame(width: 44, height: 44)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 44)
    }
}
