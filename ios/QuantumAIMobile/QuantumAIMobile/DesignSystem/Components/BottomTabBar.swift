import SwiftUI

public enum ShellTab: String, CaseIterable, Identifiable {
    case panel
    case markets
    case wallet
    case bots
    case settings

    public var id: String { rawValue }

    var title: String {
        switch self {
        case .panel:
            return "Panel"
        case .markets:
            return "Piyasalar"
        case .wallet:
            return "Cüzdan"
        case .bots:
            return "Botlar"
        case .settings:
            return "Ayarlar"
        }
    }

    var icon: String {
        switch self {
        case .panel:
            return "rectangle.grid.2x2"
        case .markets:
            return "chart.line.uptrend.xyaxis"
        case .wallet:
            return "lock.shield"
        case .bots:
            return "gearshape.2"
        case .settings:
            return "slider.horizontal.3"
        }
    }
}

public struct BottomTabBar: View {
    @Binding private var selectedTab: ShellTab

    public init(selectedTab: Binding<ShellTab>) {
        self._selectedTab = selectedTab
    }

    public var body: some View {
        HStack(spacing: QAITokens.Spacing.xs) {
            ForEach(ShellTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 16, weight: .semibold))
                        Text(tab.title)
                            .font(QAITokens.Typography.tab)
                            .lineLimit(1)
                    }
                    .foregroundStyle(selectedTab == tab ? QAITokens.Palette.backgroundBottom : QAITokens.Palette.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 54)
                    .padding(.vertical, 8)
                    .background(selectedTab == tab ? QAITokens.Palette.gold : QAITokens.Palette.tabIdle)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
            }
        }
        .padding(8)
        .background(QAITokens.Palette.card.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: QAITokens.Radius.tab, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: QAITokens.Radius.tab, style: .continuous)
                .stroke(QAITokens.Palette.stroke, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.24), radius: 18, x: 0, y: 10)
    }
}
