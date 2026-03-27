import SwiftUI

public struct PanelView: View {
    @EnvironmentObject private var env: AppEnvironment
    private static let operationsMenuAnchor = "panel-operations-menu"

    public init() {}

    private var viewState: PanelViewState {
        PanelViewState.from(environment: env)
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: QAITokens.Spacing.l) {
                    ScreenHeader(title: "Panel")

                    PanelHeroCard(
                        state: viewState,
                        refreshAction: refreshOperationalState,
                        operationsAction: {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                                proxy.scrollTo(Self.operationsMenuAnchor, anchor: .top)
                            }
                        }
                    )

                    PanelOperationsMenuCard()
                        .id(Self.operationsMenuAnchor)

                    PanelQuickStatsGrid(state: viewState)

                    PanelMarketSnapshotCard(state: viewState)

                    PanelOrdersCard(state: viewState)

                    PanelRecommendationCard(message: viewState.aiSummary)
                }
                .padding(.horizontal, QAITokens.Layout.screenPadding)
                .padding(.top, QAITokens.Spacing.s)
                .padding(.bottom, QAITokens.Layout.dockedBottomClearance)
            }
            .accessibilityIdentifier("panel-screen")
            .background(AppBackground())
            .screenNavigationChromeHidden()
        }
    }

    private func refreshOperationalState() {
        env.applyRuntimeSettings()
        env.market.refreshForActiveScene()

        if env.settings.marketBridgeEnabled {
            Task {
                await env.marketBridge.refreshNow()
            }
        }
    }
}

@MainActor
private struct PanelViewState {
    let symbol: String
    let lastPriceText: String
    let sourceText: String
    let statusText: String
    let aiSummary: String
    let activeOrders: Int
    let queueDepth: Int
    let exposureText: String
    let pnlText: String
    let successRateText: String

    static func from(environment env: AppEnvironment) -> PanelViewState {
        let lastPrice = env.market.last?.price ?? 0
        let pnl = env.bot.estimatedPnL(currentPrice: env.market.last?.price)
        let activeOrders = env.bot.activeOrders.count
        let queueDepth = env.storage.queueDepth()
        let exposure = env.bot.exposureUSD()
        let successRate = max(0, min(100, Int((1.0 - env.sync.retryRate()) * 100)))

        return PanelViewState(
            symbol: env.settings.selectedSymbol,
            lastPriceText: Self.currency(lastPrice),
            sourceText: env.market.sourceText,
            statusText: env.market.statusText,
            aiSummary: Self.summary(env: env, activeOrders: activeOrders, queueDepth: queueDepth),
            activeOrders: activeOrders,
            queueDepth: queueDepth,
            exposureText: Self.currency(exposure),
            pnlText: Self.currency(pnl),
            successRateText: "%\(successRate)"
        )
    }

    private static func summary(env: AppEnvironment, activeOrders: Int, queueDepth: Int) -> String {
        if let error = env.market.lastError, !error.isEmpty {
            return "Piyasa akisi sorunlu. Kullaniciyi teknik detaya bogmadan tekrar dene akisi goster."
        }
        if queueDepth > 0 {
            return "Outbox'ta \(queueDepth) islem bekliyor. Oncelikli aksiyon bunu temizlemek."
        }
        if activeOrders > 0 {
            return "Acik islemler var. Panel bu durumda saglik, maruziyet ve hizli durdurma aksiyonlarini one cikarmali."
        }
        return "Ana panel tek bakista saglik, piyasa ve operasyon durumu vermeli. Ikinci seviye araclari bu ekrana yigma."
    }

    private static func currency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = value >= 1000 ? 0 : 2
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}

private struct PanelHeroCard: View {
    let state: PanelViewState
    let refreshAction: () -> Void
    let operationsAction: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                VStack(alignment: .leading, spacing: QAITokens.Spacing.xs) {
                    Text("Operasyon Ozeti")
                        .font(QAITokens.Typography.caption)
                        .foregroundStyle(QAITokens.Palette.textSecondary)

                    Text("Anlik saglik, acik risk ve kritik aksiyonlar tek hero kartta toplanmali.")
                        .font(QAITokens.Typography.cardTitle)
                        .foregroundStyle(QAITokens.Palette.textPrimary)
                        .lineLimit(nil)
                }

                HStack(spacing: QAITokens.Spacing.s) {
                    StatusPill(title: state.statusText, tint: QAITokens.Palette.gold)
                    StatusPill(title: state.sourceText, tint: QAITokens.Palette.teal)
                    StatusPill(title: state.symbol, tint: QAITokens.Palette.chipBlue)
                }

                Text(state.aiSummary)
                    .font(QAITokens.Typography.body)
                    .foregroundStyle(QAITokens.Palette.textSecondary)
                    .lineLimit(nil)

                HStack(spacing: QAITokens.Spacing.m) {
                    PrimaryActionButton(title: "Sistem Sagligini Yenile", action: refreshAction)
                    PrimaryActionButton(title: "Operasyonlara Git", style: .secondary, action: operationsAction)
                }
            }
        }
    }
}

private struct PanelOperationsMenuCard: View {
    private let columns = Array(repeating: GridItem(.flexible(), spacing: QAITokens.Spacing.s), count: 3)

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                Label("Operasyon Menüsü", systemImage: "square.grid.2x2")
                    .font(QAITokens.Typography.cardTitle)
                    .foregroundStyle(QAITokens.Palette.textPrimary)

                LazyVGrid(columns: columns, spacing: QAITokens.Spacing.s) {
                    NavigationLink {
                        MarketBridgeView(showsBackButton: true)
                    } label: {
                        PanelOperationTile(title: "Market Bridge", icon: "globe", tint: QAITokens.Palette.chipBlue)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("panel-op-market-bridge")

                    NavigationLink {
                        IntelligenceCenterView()
                    } label: {
                        PanelOperationTile(title: "Beyin", icon: "brain.head.profile", tint: QAITokens.Palette.chipTeal)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("panel-op-intelligence")

                    NavigationLink {
                        StrategyLibraryView()
                    } label: {
                        PanelOperationTile(title: "Preset", icon: "bolt.horizontal.circle", tint: Color.white.opacity(0.18))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("panel-op-preset")

                    NavigationLink {
                        RunbookCenterView()
                    } label: {
                        PanelOperationTile(title: "Runbook", icon: "list.bullet.clipboard", tint: QAITokens.Palette.chipAmber)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("panel-op-runbook")

                    NavigationLink {
                        PanelTrainingDemoScreen()
                    } label: {
                        PanelOperationTile(title: "Test & Demo", icon: "play.rectangle", tint: QAITokens.Palette.cardElevated)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("panel-op-test-demo")

                    NavigationLink {
                        SettingsView(showsBackButton: true)
                    } label: {
                        PanelOperationTile(title: "Ayarlar", icon: "slider.horizontal.3", tint: Color.white.opacity(0.18))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("panel-op-settings")

                    NavigationLink {
                        SimulationsHubView()
                    } label: {
                        PanelOperationTile(title: "Sim Stack", icon: "square.stack.3d.up", tint: Color(red: 41.0 / 255.0, green: 95.0 / 255.0, blue: 134.0 / 255.0))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("panel-op-sim-stack")

                    NavigationLink {
                        HQAdminView()
                    } label: {
                        PanelOperationTile(title: "HQ Admin", icon: "shield.lefthalf.filled", tint: Color(red: 83.0 / 255.0, green: 46.0 / 255.0, blue: 88.0 / 255.0))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("panel-op-hq-admin")
                }
            }
        }
    }
}

private struct PanelQuickStatsGrid: View {
    let state: PanelViewState

    var body: some View {
        HStack(spacing: QAITokens.Spacing.s) {
            PanelStatCard(title: "PnL", value: state.pnlText, tint: QAITokens.Palette.chipBlue)
            PanelStatCard(title: "Maruziyet", value: state.exposureText, tint: QAITokens.Palette.chipTeal)
            PanelStatCard(title: "Acik Emir", value: "\(state.activeOrders)", tint: QAITokens.Palette.chipAmber)
            PanelStatCard(title: "Basari", value: state.successRateText, tint: QAITokens.Palette.cardElevated)
        }
    }
}

private struct PanelMarketSnapshotCard: View {
    let state: PanelViewState

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                Text("Canli Piyasa")
                    .font(QAITokens.Typography.cardTitle)
                    .foregroundStyle(QAITokens.Palette.textPrimary)

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(state.symbol)
                            .font(QAITokens.Typography.caption)
                            .foregroundStyle(QAITokens.Palette.textSecondary)
                        Text(state.lastPriceText)
                            .font(QAITokens.Typography.statValue)
                            .foregroundStyle(QAITokens.Palette.textPrimary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 6) {
                        Text(state.sourceText)
                            .font(QAITokens.Typography.caption)
                            .foregroundStyle(QAITokens.Palette.textSecondary)
                        Text(state.statusText)
                            .font(QAITokens.Typography.bodyStrong)
                            .foregroundStyle(QAITokens.Palette.gold)
                    }
                }

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(QAITokens.Palette.cardElevated)
                    .frame(height: 120)
                    .overlay(
                        Text("Mini chart / live state template")
                            .font(QAITokens.Typography.caption)
                            .foregroundStyle(QAITokens.Palette.textSecondary)
                    )
            }
        }
    }
}

private struct PanelOrdersCard: View {
    let state: PanelViewState

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                HStack {
                    Text("Acik Emirler")
                        .font(QAITokens.Typography.cardTitle)
                        .foregroundStyle(QAITokens.Palette.textPrimary)
                    Spacer()
                    Text("Outbox: \(state.queueDepth)")
                        .font(QAITokens.Typography.caption)
                        .foregroundStyle(QAITokens.Palette.textSecondary)
                }

                if state.activeOrders == 0 {
                    Text("Acik emir yok. Bu blok empty state gorunumuyle yeniden kullanilmali.")
                        .font(QAITokens.Typography.body)
                        .foregroundStyle(QAITokens.Palette.textSecondary)
                        .lineLimit(nil)
                } else {
                    ForEach(0..<min(state.activeOrders, 3), id: \.self) { index in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(state.symbol)
                                    .font(QAITokens.Typography.bodyStrong)
                                    .foregroundStyle(QAITokens.Palette.textPrimary)
                                Text(index == 0 ? "GRID" : "BUY")
                                    .font(QAITokens.Typography.caption)
                                    .foregroundStyle(QAITokens.Palette.textSecondary)
                            }
                            Spacer()
                            Circle()
                                .fill(index == 0 ? QAITokens.Palette.teal : QAITokens.Palette.gold)
                                .frame(width: 10, height: 10)
                        }
                        .padding(.vertical, 10)
                    }
                }
            }
        }
    }
}

private struct PanelRecommendationCard: View {
    let message: String

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: QAITokens.Spacing.s) {
                Text("AI Tavsiye")
                    .font(QAITokens.Typography.cardTitle)
                    .foregroundStyle(QAITokens.Palette.textPrimary)
                Text(message)
                    .font(QAITokens.Typography.body)
                    .foregroundStyle(QAITokens.Palette.textSecondary)
                    .lineLimit(nil)
            }
        }
    }
}

private struct PanelOperationTile: View {
    let title: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: QAITokens.Spacing.s) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(QAITokens.Palette.textPrimary)

            Spacer(minLength: 0)

            Text(title)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(QAITokens.Palette.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .padding(18)
        .background(tint)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(QAITokens.Palette.stroke, lineWidth: 1)
        )
    }
}

private struct PanelStatCard: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(QAITokens.Typography.caption)
                .foregroundStyle(QAITokens.Palette.textSecondary)
                .lineLimit(1)
            Text(value)
                .font(QAITokens.Typography.cardTitle)
                .foregroundStyle(QAITokens.Palette.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding(QAITokens.Spacing.m)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .background(tint)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct StatusPill: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(QAITokens.Typography.caption)
            .foregroundStyle(QAITokens.Palette.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(tint)
            .clipShape(Capsule())
    }
}

private struct PanelTrainingDemoScreen: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: QAITokens.Spacing.l) {
                ScreenHeader(title: "Test & Demo", showsBackButton: true, onBack: { dismiss() })
                TrainingDocumentViewer()
            }
            .padding(.horizontal, QAITokens.Layout.screenPadding)
            .padding(.top, QAITokens.Spacing.s)
            .padding(.bottom, QAITokens.Layout.dockedBottomClearance)
        }
        .accessibilityIdentifier("test-demo-screen")
        .background(AppBackground())
        .screenNavigationChromeHidden()
    }
}

#Preview {
    NavigationStack {
        PanelView()
            .environmentObject(AppEnvironment.liveInSim())
    }
}
