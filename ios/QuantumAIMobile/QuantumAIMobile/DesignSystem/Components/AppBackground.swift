import SwiftUI

public struct AppBackground: View {
    public init() {}

    public var body: some View {
        ZStack {
            QAITokens.shellGradient
            LinearGradient(
                colors: [QAITokens.Palette.backgroundGlow, .clear, .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}
