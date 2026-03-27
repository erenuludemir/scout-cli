import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public enum QAITheme {
    public static let background = Color(red: 11.0 / 255.0, green: 16.0 / 255.0, blue: 29.0 / 255.0)
    public static let cardBg = Color(red: 20.0 / 255.0, green: 28.0 / 255.0, blue: 45.0 / 255.0)
    public static let shellTop = Color(red: 22.0 / 255.0, green: 33.0 / 255.0, blue: 56.0 / 255.0)
    public static let shellBottom = Color(red: 7.0 / 255.0, green: 11.0 / 255.0, blue: 22.0 / 255.0)
    public static let surface = Color(red: 18.0 / 255.0, green: 27.0 / 255.0, blue: 45.0 / 255.0)
    public static let surfaceElevated = Color(red: 24.0 / 255.0, green: 34.0 / 255.0, blue: 56.0 / 255.0)
    public static let surfaceMuted = Color(red: 38.0 / 255.0, green: 52.0 / 255.0, blue: 80.0 / 255.0)
    public static let panelBlue = Color(red: 71.0 / 255.0, green: 102.0 / 255.0, blue: 166.0 / 255.0)
    public static let border = Color(red: 159.0 / 255.0, green: 177.0 / 255.0, blue: 208.0 / 255.0).opacity(0.13)
    public static let accent = Color(red: 229.0 / 255.0, green: 184.0 / 255.0, blue: 111.0 / 255.0)
    public static let accentSoft = Color(red: 244.0 / 255.0, green: 210.0 / 255.0, blue: 151.0 / 255.0)
    public static let success = Color(red: 52.0 / 255.0, green: 201.0 / 255.0, blue: 118.0 / 255.0)
    public static let warning = Color(red: 255.0 / 255.0, green: 124.0 / 255.0, blue: 67.0 / 255.0)
    public static let error = Color(red: 239.0 / 255.0, green: 71.0 / 255.0, blue: 111.0 / 255.0)
    public static let textPrimary = Color.white
    public static let textSecondary = Color(red: 180.0 / 255.0, green: 189.0 / 255.0, blue: 209.0 / 255.0)
    public static let shellHorizontalPadding: CGFloat = 14
    public static let shellTopPadding: CGFloat = 10
    public static let compactCardPadding: CGFloat = 14
    public static let compactCornerRadius: CGFloat = 20
    public static let compactInnerCornerRadius: CGFloat = 16
    public static let compactButtonVerticalPadding: CGFloat = 11
    public static let compactChipHorizontalPadding: CGFloat = 10
    public static let compactChipVerticalPadding: CGFloat = 6
    public static let dockedBottomPadding: CGFloat = 118

    public static let heroTitleFont = Font.system(size: 27, weight: .semibold, design: .rounded)
    public static let sectionTitleFont = Font.system(.subheadline, design: .rounded).weight(.semibold)
    public static let bodyFont = Font.system(.footnote, design: .rounded)
    public static let emphasisFont = Font.system(.subheadline, design: .rounded).weight(.medium)
    public static let buttonFont = Font.system(.subheadline, design: .rounded).weight(.semibold)
    public static let metricFont = Font.system(.subheadline, design: .rounded).weight(.semibold)
    public static let captionFont = Font.system(.caption, design: .rounded).weight(.medium)

    public static let shellGradient = LinearGradient(
        colors: [shellTop, background, shellBottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    public static let cardGradient = LinearGradient(
        colors: [surfaceElevated, surface],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    public static let shellOverlay = LinearGradient(
        colors: [panelBlue.opacity(0.22), .clear, .clear],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
