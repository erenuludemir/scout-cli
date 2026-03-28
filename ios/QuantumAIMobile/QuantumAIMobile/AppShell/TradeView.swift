import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct TradeView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var actionMessage = "Strateji merkezi hazir"

    private let showsBackButton: Bool

    public init(showsBackButton: Bool = false) {
        self.showsBackButton = showsBackButton
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: QAITokens.Spacing.l) {
                ScreenHeader(title: "Botlar", showsBackButton: showsBackButton, onBack: { dismiss() })

                TradeHeroCard(
                    activeStrategies: env.bot.activeStrategyCount + (env.copyTrade.isActive ? 1 : 0),
                    exposure: env.bot.exposureUSD(),
                    estimatedPnL: env.bot.estimatedPnL(currentPrice: env.market.last?.price),
                    queueDepth: env.storage.queueDepth(),
                    modeText: env.runtimeUsesSimulation ? "Simulasyon" : "Canli"
                )

                TradeStrategyCard(
                    title: "DCA Motoru",
                    subtitle: "Kademe kademe maliyet dusurme",
                    metrics: [
                        ("Tutar", String(format: "$%.0f", env.settings.dcaAmount)),
                        ("Periyot", "\(env.settings.dcaPeriodSec) sn")
                    ],
                    isActive: env.bot.isDCAActive,
                    startTitle: "Baslat",
                    stopTitle: "Durdur",
                    startAction: startDCA,
                    stopAction: {
                        env.bot.stopDCA()
                        actionMessage = "DCA durduruldu"
                    }
                )

                TradeStrategyCard(
                    title: "Grid Engine",
                    subtitle: "Band icinde otomatik kademeli islem",
                    metrics: [
                        ("Alt Bant", String(format: "$%.0f", env.settings.gridLower)),
                        ("Ust Bant", String(format: "$%.0f", env.settings.gridUpper)),
                        ("Kademe", "\(env.settings.gridSteps)")
                    ],
                    isActive: env.bot.isGridActive,
                    startTitle: "Kur",
                    stopTitle: "Kapat",
                    startAction: startGrid,
                    stopAction: {
                        env.bot.stopGrid()
                        actionMessage = "Grid stratejisi kapatildi"
                    }
                )

                TradeStrategyCard(
                    title: "Copy Trade",
                    subtitle: "Leader akisina bagli hizli kopya modu",
                    metrics: [
                        ("Kaynak", env.settings.selectedSymbol),
                        ("Oran", String(format: "%.2fx", env.settings.copyRatio))
                    ],
                    isActive: env.copyTrade.isActive,
                    startTitle: "Baslat",
                    stopTitle: "Durdur",
                    startAction: startCopyTrade,
                    stopAction: {
                        env.copyTrade.stop()
                        actionMessage = "CopyTrade durduruldu"
                    }
                )

                GlassCard {
                    VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                        Label("Risk ve Operasyon", systemImage: "shield.lefthalf.filled")
                            .font(QAITokens.Typography.cardTitle)
                            .foregroundStyle(QAITokens.Palette.textPrimary)

                        Text(actionMessage)
                            .font(QAITokens.Typography.body)
                            .foregroundStyle(QAITokens.Palette.textSecondary)

                        HStack(spacing: QAITokens.Spacing.s) {
                            NavigationLink {
                                MarketBridgeView(showsBackButton: true)
                            } label: {
                                TradeUtilityTile(
                                    title: "Market Bridge",
                                    subtitle: env.settings.selectedSymbol,
                                    tint: QAITokens.Palette.chipBlue
                                )
                            }
                            .buttonStyle(.plain)

                            NavigationLink {
                                TrainingDocumentViewer()
                            } label: {
                                TradeUtilityTile(
                                    title: "Test ve Demo",
                                    subtitle: "HTML rehber + adimlar",
                                    tint: QAITokens.Palette.cardElevated
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        HStack(spacing: QAITokens.Spacing.s) {
                            NavigationLink {
                                OrdersView()
                            } label: {
                                TradeUtilityTile(
                                    title: "Aktif Emirler",
                                    subtitle: "\(env.bot.activeOrders.count) acik kayit",
                                    tint: QAITokens.Palette.cardElevated
                                )
                            }
                            .buttonStyle(.plain)

                            Button {
                                env.storage.clearOutbox()
                                actionMessage = "Outbox temizlendi"
                            } label: {
                                TradeUtilityTile(
                                    title: "Outbox",
                                    subtitle: "\(env.storage.queueDepth()) bekleyen",
                                    tint: QAITokens.Palette.chipAmber
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        HStack(spacing: QAITokens.Spacing.s) {
                            NavigationLink {
                                StrategyLibraryView()
                            } label: {
                                TradeUtilityTile(
                                    title: "Preset Merkezi",
                                    subtitle: "\(env.training.guide.presets.count) hazir strateji",
                                    tint: QAITokens.Palette.gold.opacity(0.24)
                                )
                            }
                            .buttonStyle(.plain)

                            NavigationLink {
                                RunbookCenterView()
                            } label: {
                                TradeUtilityTile(
                                    title: "Runbook",
                                    subtitle: "Operasyon prosedurleri",
                                    tint: QAITokens.Palette.cardElevated
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            env.bot.stopAll()
                            env.copyTrade.stop()
                            actionMessage = "Panik stop calisti, tum botlar durdu"
                        } label: {
                            HStack(spacing: QAITokens.Spacing.s) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text("Panik Stop")
                                    .font(QAITokens.Typography.bodyStrong)
                                Spacer()
                                Text("Tum stratejiler")
                                    .font(QAITokens.Typography.caption)
                            }
                            .foregroundStyle(QAITokens.Palette.backgroundBottom)
                            .padding(QAITokens.Spacing.m)
                            .frame(maxWidth: .infinity)
                            .background(QAITokens.Palette.warning.opacity(0.9))
                            .clipShape(RoundedRectangle(cornerRadius: QAITokens.Radius.button, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !env.bot.activeOrders.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                            Label("Canli Pozisyonlar", systemImage: "list.bullet.rectangle.portrait")
                                .font(QAITokens.Typography.cardTitle)
                                .foregroundStyle(QAITokens.Palette.textPrimary)

                            ForEach(env.bot.activeOrders.prefix(4)) { order in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(order.symbol)
                                            .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                                            .foregroundStyle(QAITokens.Palette.textPrimary)
                                        Text(order.side)
                                            .font(QAITokens.Typography.caption)
                                            .foregroundStyle(QAITokens.Palette.textSecondary)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text(String(format: "$%.2f", order.price))
                                            .font(.system(.subheadline, design: .monospaced))
                                            .foregroundStyle(QAITokens.Palette.textPrimary)
                                        Text(String(format: "%.4f", order.amount))
                                            .font(QAITokens.Typography.caption)
                                            .foregroundStyle(QAITokens.Palette.textSecondary)
                                    }
                                }
                                .padding(QAITokens.Spacing.m)
                                .background(QAITokens.Palette.cardElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, QAITokens.Layout.screenPadding)
            .padding(.top, QAITokens.Spacing.s)
            .padding(.bottom, QAITokens.Layout.dockedBottomClearance)
        }
        .background(AppBackground())
        .screenNavigationChromeHidden()
    }

    private func startDCA() {
        guard !env.bot.isDCAActive else {
            actionMessage = "DCA zaten aktif"
            return
        }
        env.bot.startDCA(amount: env.settings.dcaAmount, periodSec: env.settings.dcaPeriodSec)
        actionMessage = "DCA stratejisi baslatildi"
    }

    private func startGrid() {
        guard !env.bot.isGridActive else {
            actionMessage = "Grid zaten aktif"
            return
        }
        env.bot.startGrid(lower: env.settings.gridLower, upper: env.settings.gridUpper, steps: env.settings.gridSteps)
        actionMessage = "Grid stratejisi kuruldu"
    }

    private func startCopyTrade() {
        guard !env.copyTrade.isActive else {
            actionMessage = "CopyTrade zaten aktif"
            return
        }
        env.copyTrade.start(source: env.settings.selectedSymbol, ratio: env.settings.copyRatio)
        actionMessage = "CopyTrade baslatildi"
    }
}

private struct TradeHeroCard: View {
    let activeStrategies: Int
    let exposure: Double
    let estimatedPnL: Double
    let queueDepth: Int
    let modeText: String

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                HStack(alignment: .top, spacing: QAITokens.Spacing.s) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Strateji Komuta Merkezi")
                            .font(QAITokens.Typography.largeTitle)
                            .foregroundStyle(QAITokens.Palette.textPrimary)
                        Text("Bot start/stop, risk kesme ve canli maruziyet ayni ekranda.")
                            .font(QAITokens.Typography.body)
                            .foregroundStyle(QAITokens.Palette.textSecondary)
                    }

                    Spacer()

                    AppMarkView(size: 42)
                }

                HStack(spacing: QAITokens.Spacing.s) {
                    TradeHeroMetric(title: "Aktif", value: "\(activeStrategies)", tint: QAITokens.Palette.gold)
                    TradeHeroMetric(title: "Outbox", value: "\(queueDepth)", tint: QAITokens.Palette.warning)
                    TradeHeroMetric(title: "Mod", value: modeText, tint: modeText == "Canli" ? QAITokens.Palette.teal : QAITokens.Palette.cardElevated)
                }

                HStack(spacing: QAITokens.Spacing.s) {
                    ProfitPill(title: "Maruziyet", value: String(format: "$%.0f", exposure), tint: QAITokens.Palette.textSecondary)
                    ProfitPill(
                        title: "Tahmini PnL",
                        value: String(format: "%@%.2f", estimatedPnL >= 0 ? "+" : "", estimatedPnL),
                        tint: estimatedPnL >= 0 ? QAITokens.Palette.teal : QAITokens.Palette.warning
                    )
                }
            }
        }
    }
}

private struct TradeHeroMetric: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(QAITokens.Typography.caption)
                .foregroundStyle(QAITokens.Palette.textSecondary)
            Text(value)
                .font(QAITokens.Typography.cardTitle)
                .foregroundStyle(QAITokens.Palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(QAITokens.Spacing.m)
        .background(tint.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct ProfitPill: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(QAITokens.Typography.caption)
                .foregroundStyle(QAITokens.Palette.textSecondary)
            Text(value)
                .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(QAITokens.Spacing.m)
        .background(QAITokens.Palette.cardElevated)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct TradeStrategyCard: View {
    let title: String
    let subtitle: String
    let metrics: [(String, String)]
    let isActive: Bool
    let startTitle: String
    let stopTitle: String
    let startAction: () -> Void
    let stopAction: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(QAITokens.Typography.cardTitle)
                            .foregroundStyle(QAITokens.Palette.textPrimary)
                        Text(subtitle)
                            .font(QAITokens.Typography.body)
                            .foregroundStyle(QAITokens.Palette.textSecondary)
                    }
                    Spacer()
                    Text(isActive ? "AKTIF" : "BEKLEME")
                        .font(QAITokens.Typography.caption)
                        .foregroundStyle(isActive ? QAITokens.Palette.backgroundBottom : QAITokens.Palette.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isActive ? QAITokens.Palette.teal : QAITokens.Palette.cardElevated)
                        .clipShape(Capsule())
                }

                ForEach(metrics, id: \.0) { item in
                    HStack {
                        Text(item.0)
                            .font(QAITokens.Typography.body)
                            .foregroundStyle(QAITokens.Palette.textSecondary)
                        Spacer()
                        Text(item.1)
                            .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                            .foregroundStyle(QAITokens.Palette.textPrimary)
                    }
                }

                HStack(spacing: QAITokens.Spacing.s) {
                    PrimaryActionButton(title: startTitle) {
                        startAction()
                    }
                    .disabled(isActive)
                    .opacity(isActive ? 0.45 : 1)

                    PrimaryActionButton(title: stopTitle, style: .secondary) {
                        stopAction()
                    }
                    .disabled(!isActive)
                    .opacity(!isActive ? 0.45 : 1)
                }
            }
        }
    }
}

private struct TradeUtilityTile: View {
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(QAITokens.Typography.cardTitle)
                .foregroundStyle(QAITokens.Palette.textPrimary)
            Text(subtitle)
                .font(QAITokens.Typography.caption)
                .foregroundStyle(QAITokens.Palette.textSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
        .padding(QAITokens.Spacing.m)
        .background(tint)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
