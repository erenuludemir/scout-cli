import SwiftUI
@available(iOS 17.0, macOS 14.0, *)

public struct MetricRow: View {
    let title: String
    let value: String

    public init(title: String, value: String) {
        self.title = title
        self.value = value
    }

    public var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(QAITheme.textPrimary)
            Spacer()
            Text(value)
                .bold()
                .foregroundStyle(QAITheme.textPrimary)
        }
    }
}
