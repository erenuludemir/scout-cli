import SwiftUI
@available(iOS 17.0, macOS 14.0, *)

public struct EmptyStateView: View {
    let text: String

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(text)
                .font(QAITheme.bodyFont)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}
