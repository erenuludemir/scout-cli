import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct AppMarkView: View {
    let size: CGFloat

    public init(size: CGFloat = 44) {
        self.size = size
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [QAITheme.surfaceElevated, QAITheme.panelBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .stroke(QAITheme.accentSoft.opacity(0.34), lineWidth: 1)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [QAITheme.accent, QAITheme.accentSoft],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size * 0.5, height: size * 0.5)
                .offset(x: size * 0.12, y: -size * 0.12)

            VStack(alignment: .leading, spacing: size * 0.01) {
                Text("Q")
                    .font(.system(size: size * 0.34, weight: .black, design: .serif))
                Text("AI")
                    .font(.system(size: size * 0.14, weight: .bold, design: .rounded))
                    .tracking(size * 0.02)
            }
            .foregroundStyle(QAITheme.background)
            .offset(x: -size * 0.06, y: size * 0.04)
        }
        .frame(width: size, height: size)
        .shadow(color: QAITheme.panelBlue.opacity(0.22), radius: size * 0.16, x: 0, y: size * 0.1)
    }
}
