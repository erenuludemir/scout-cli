import SwiftUI

public enum QAITokens {
    public enum Palette {
        public static let backgroundTop = Color(red: 17.0 / 255.0, green: 28.0 / 255.0, blue: 52.0 / 255.0)
        public static let backgroundBottom = Color(red: 6.0 / 255.0, green: 10.0 / 255.0, blue: 22.0 / 255.0)
        public static let backgroundGlow = Color(red: 61.0 / 255.0, green: 102.0 / 255.0, blue: 173.0 / 255.0).opacity(0.18)
        public static let card = Color(red: 16.0 / 255.0, green: 27.0 / 255.0, blue: 58.0 / 255.0).opacity(0.88)
        public static let cardElevated = Color(red: 22.0 / 255.0, green: 35.0 / 255.0, blue: 71.0 / 255.0).opacity(0.94)
        public static let stroke = Color.white.opacity(0.08)
        public static let textPrimary = Color.white
        public static let textSecondary = Color(red: 182.0 / 255.0, green: 193.0 / 255.0, blue: 214.0 / 255.0)
        public static let gold = Color(red: 230.0 / 255.0, green: 190.0 / 255.0, blue: 116.0 / 255.0)
        public static let teal = Color(red: 64.0 / 255.0, green: 175.0 / 255.0, blue: 154.0 / 255.0)
        public static let warning = Color(red: 233.0 / 255.0, green: 129.0 / 255.0, blue: 72.0 / 255.0)
        public static let chipBlue = Color(red: 67.0 / 255.0, green: 88.0 / 255.0, blue: 134.0 / 255.0).opacity(0.55)
        public static let chipTeal = Color(red: 44.0 / 255.0, green: 91.0 / 255.0, blue: 89.0 / 255.0).opacity(0.72)
        public static let chipAmber = Color(red: 95.0 / 255.0, green: 64.0 / 255.0, blue: 49.0 / 255.0).opacity(0.8)
        public static let tabIdle = Color(red: 18.0 / 255.0, green: 25.0 / 255.0, blue: 44.0 / 255.0)
    }

    public enum Spacing {
        public static let xs: CGFloat = 8
        public static let s: CGFloat = 12
        public static let m: CGFloat = 16
        public static let l: CGFloat = 20
        public static let xl: CGFloat = 24
        public static let xxl: CGFloat = 32
    }

    public enum Radius {
        public static let chip: CGFloat = 16
        public static let button: CGFloat = 18
        public static let card: CGFloat = 26
        public static let tab: CGFloat = 28
    }

    public enum Layout {
        public static let screenPadding: CGFloat = 20
        public static let cardPadding: CGFloat = 20
        public static let dockedBottomClearance: CGFloat = 116
        public static let tabBarOuterPadding: CGFloat = 14
    }

    public enum Typography {
        public static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
        public static let screenTitle = Font.system(size: 20, weight: .semibold, design: .rounded)
        public static let cardTitle = Font.system(size: 17, weight: .semibold, design: .rounded)
        public static let statValue = Font.system(size: 28, weight: .bold, design: .rounded)
        public static let body = Font.system(size: 15, weight: .regular, design: .rounded)
        public static let bodyStrong = Font.system(size: 15, weight: .semibold, design: .rounded)
        public static let caption = Font.system(size: 13, weight: .medium, design: .rounded)
        public static let tab = Font.system(size: 13, weight: .semibold, design: .rounded)
    }

    public static let shellGradient = LinearGradient(
        colors: [Palette.backgroundTop, Palette.backgroundBottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
