import SwiftUI

public struct OutboxAlertView: View {
    let count: Int
    let action: () -> Void

    public init(count: Int, action: @escaping () -> Void) {
        self.count = count
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                Text("Gönderilmeyi bekleyen \(count) işleminiz var!")
                    .bold()
                Spacer()
                Image(systemName: "chevron.right")
            }
            .padding()
            .background(QAITheme.warning.opacity(0.9))
            .foregroundStyle(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
