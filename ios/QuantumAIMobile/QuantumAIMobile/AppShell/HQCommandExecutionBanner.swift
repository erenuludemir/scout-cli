import SwiftUI

struct HQCommandExecutionBanner: View {
    let banner: HQCommandBannerModel

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: banner.state.systemImage)
                .font(.system(size: 14, weight: .bold))
            VStack(alignment: .leading, spacing: 2) {
                Text(banner.title)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                Text(banner.detail)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Text(banner.state.title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
        }
        .foregroundStyle(QAITokens.Palette.textPrimary)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(banner.state.tint.opacity(0.34))
        .overlay(
            Capsule()
                .stroke(banner.state.tint.opacity(0.52), lineWidth: 1)
        )
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.18), radius: 14, x: 0, y: 8)
    }
}
