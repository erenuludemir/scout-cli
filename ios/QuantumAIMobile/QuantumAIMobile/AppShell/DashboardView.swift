import SwiftUI
import Combine

public struct DashboardView: View {
    @EnvironmentObject private var env: AppEnvironment
    @ObservedObject private var branding = BrandingAndVoiceEngine.shared
    @ObservedObject private var hq = GlobalSinirSistemi.paylasilan
    @ObservedObject private var wealthBridge = WealthBridge.shared

    @State private var aiAdvice = "Panel hazırlanıyor..."
    @State private var panelStatus = "Piyasa akışı bekleniyor"
    @State private var chartData: [PnLData] = []
    @State private var baselinePrice: Double?
    @State private var isCopyTradeActive = false

    private let maxChartPoints = 36

    public init() {}

    public var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 18) {
                DashboardHeroCard(
                    partnerName: branding.partnerName,
                    brandLogo: branding.brandLogo,
                    brandColor: branding.primaryColor,
                    isPaperTrading: env.settings.isPaperTrading,
                    isAuthenticated: env.settings.isAuthenticated,
                    lastSync: hq.sonSenkronizasyon,
                    advice: aiAdvice,
                    selectedSymbol: env.settings.selectedSymbol,
                    dcaAmount: env.settings.dcaAmount,
                    dcaPeriodSec: env.settings.dcaPeriodSec
                )

                OperationsMenuCard()

                MarketPulseCard(
                    market: env.market,
                    watchlist: env.watchlist,
                    selectedSymbol: env.settings.selectedSymbol,
                    chartData: chartData,
                    baselinePrice: baselinePrice,
                    onSelectSymbol: selectSymbol
                )

                PortfolioSnapshotCard(
                    estimatedPnL: env.bot.estimatedPnL(currentPrice: env.market.last?.price),
                    exposure: env.bot.exposureUSD(),
                    activeStrategies: env.bot.activeStrategyCount + (isCopyTradeActive ? 1 : 0),
                    queueDepth: env.storage.queueDepth(),
                    retryRate: env.sync.retryRate()
                )

                IntelligenceCard(
                    status: panelStatus,
                    aiAdvice: aiAdvice,
                    isLicensed: env.settings.isAuthenticated,
                    activeSymbol: env.settings.selectedSymbol
                )

                NavigationLink {
                    MarketBridgeView()
                } label: {
                    LiveBridgeCalloutCard(
                        snapshot: env.marketBridge.snapshot,
                        isEnabled: env.settings.marketBridgeEnabled,
                        lastError: env.marketBridge.lastError
                    )
                }
                .buttonStyle(.plain)

                KnowledgeHubCard(recommendation: primaryRecommendation)

                DashboardActionsCard(
                    queueDepth: env.storage.queueDepth(),
                    dcaAmount: env.settings.dcaAmount,
                    gridSteps: env.settings.gridSteps,
                    copyRatio: env.settings.copyRatio,
                    isDCAActive: env.bot.isDCAActive,
                    isGridActive: env.bot.isGridActive,
                    isCopyTradeActive: isCopyTradeActive,
                    onStartDCA: startDCA,
                    onStartGrid: startGrid,
                    onToggleCopyTrade: toggleCopyTrade,
                    onExportCSV: exportOrdersCSV,
                    onClearOutbox: clearOutbox,
                    onPanicStop: panicStop
                )

                OperationsHealthCard(
                    health: env.health,
                    hq: hq,
                    isPaperTrading: env.runtimeUsesSimulation
                )

                EnterpriseTelemetryCard(hq: hq, wealthBridge: wealthBridge)

                RuntimeMetricsCard()

                if env.simulations.totalModuleCount > 0 {
                    NavigationLink {
                        SimulationsHubView()
                    } label: {
                        SimulationStatusCard()
                    }
                    .buttonStyle(.plain)
                }

                NetworkMonitorView()

                SecurityMonitorView()

                NeuroVisorView()

                SystemHealthView()

                QuantumIntelView()

                ActiveOrdersCard(bot: env.bot)
            }
            .padding(.horizontal, QAITheme.shellHorizontalPadding)
            .padding(.top, QAITheme.shellTopPadding)
            .padding(.bottom, QAITheme.dockedBottomPadding)
        }
        .background(QAITheme.shellGradient.ignoresSafeArea())
        .navigationTitle("Panel")
        .qaiNavigationTitleDisplayMode(.large)
        .task {
            env.training.loadIfNeeded()
            isCopyTradeActive = env.copyTrade.isActive
            seedChartIfNeeded()
            refreshAdvice()
            env.applyRuntimeSettings()
        }
        .onReceive(env.market.$last.compactMap { $0 }) { tick in
            appendTick(tick)
            wealthBridge.evaluateWithdrawal(currentProfit: env.bot.estimatedPnL(currentPrice: tick.price))
            refreshAdvice(latestTick: tick)
        }
        .onReceive(env.bot.$activeOrders) { _ in
            refreshAdvice()
        }
        .onReceive(env.storage.$outbox) { _ in
            refreshAdvice()
        }
        .onReceive(env.copyTrade.$isActive) { value in
            isCopyTradeActive = value
            refreshAdvice()
        }
    }

    private func selectSymbol(_ symbol: String) {
        guard env.settings.selectedSymbol != symbol else { return }
        env.settings.selectedSymbol = symbol
        panelStatus = "\(symbol) izlemeye alındı"
        baselinePrice = nil
        chartData.removeAll()
        env.applyRuntimeSettings()
    }

    private func startDCA() {
        guard !env.bot.isDCAActive else {
            panelStatus = "DCA zaten aktif"
            return
        }
        env.bot.startDCA(amount: env.settings.dcaAmount, periodSec: env.settings.dcaPeriodSec)
        panelStatus = "DCA emri kuyruklandı"
        refreshAdvice()
    }

    private func startGrid() {
        guard !env.bot.isGridActive else {
            panelStatus = "Grid zaten aktif"
            return
        }
        env.bot.startGrid(lower: env.settings.gridLower, upper: env.settings.gridUpper, steps: env.settings.gridSteps)
        panelStatus = "Grid stratejisi başlatıldı"
        refreshAdvice()
    }

    private func toggleCopyTrade() {
        if isCopyTradeActive {
            env.copyTrade.stop()
            panelStatus = "CopyTrade durduruldu"
        } else {
            env.copyTrade.start(source: env.settings.selectedSymbol, ratio: env.settings.copyRatio)
            panelStatus = "CopyTrade başlatıldı"
        }
        refreshAdvice()
    }

    private func exportOrdersCSV() {
        if let url = env.storage.exportOrdersCSV() {
            panelStatus = "CSV hazır: \(url.lastPathComponent)"
        } else {
            panelStatus = "CSV dışa aktarma başarısız"
        }
    }

    private func clearOutbox() {
        env.storage.clearOutbox()
        panelStatus = "Outbox temizlendi"
        refreshAdvice()
    }

    private func panicStop() {
        env.bot.stopAll()
        env.copyTrade.stop()
        panelStatus = "Tüm stratejiler durduruldu"
        refreshAdvice()
    }

    private func seedChartIfNeeded() {
        guard chartData.isEmpty else { return }
        let now = Date()
        chartData = (0..<12).map { offset in
            PnLData(time: now.addingTimeInterval(Double(offset - 11) * 60), value: 0)
        }
    }

    private func appendTick(_ tick: Tick) {
        if baselinePrice == nil {
            baselinePrice = tick.price
            chartData = [
                PnLData(time: tick.ts.addingTimeInterval(-60), value: 0),
                PnLData(time: tick.ts, value: 0)
            ]
            return
        }

        let base = baselinePrice ?? tick.price
        chartData.append(PnLData(time: tick.ts, value: tick.price - base))
        if chartData.count > maxChartPoints {
            chartData.removeFirst(chartData.count - maxChartPoints)
        }
    }

    private func refreshAdvice(latestTick: Tick? = nil) {
        if let recommendation = primaryRecommendation {
            aiAdvice = recommendation.summary
            return
        }

        let activeOrders = env.bot.activeOrders.count
        let queueDepth = env.storage.queueDepth()
        let retryRate = env.sync.retryRate()

        if !env.settings.isAuthenticated {
            aiAdvice = "Lisans merkezi üzerinden aktivasyon tamamlandığında premium bot akışları kalıcı açılır."
        } else if retryRate > 0.25 {
            aiAdvice = "Senkronizasyon tekrar deniyor. Outbox'u izleyin ve panik stopu hazır tutun."
        } else if queueDepth > 0 {
            aiAdvice = "Outbox'ta \(queueDepth) emir bekliyor. CSV alımı veya temizleme aksiyonu kullanabilirsiniz."
        } else if activeOrders > 0 {
            aiAdvice = "\(activeOrders) aktif emir izleniyor. Canlı kar/zarar için strateji merkezi açık tutulmalı."
        } else if env.runtimeUsesSimulation {
            aiAdvice = "Sim mod açık. DCA ve Grid ile sistemi güvenli şekilde test edebilirsiniz."
        } else if let tick = latestTick ?? env.market.last {
            aiAdvice = "\(env.settings.selectedSymbol) fiyatı \(formatCurrency(tick.price)) seviyesinde. Kademeli giriş önerilir."
        } else {
            aiAdvice = "Piyasa verisi bekleniyor. İlk tick geldikten sonra panel canlı hesaplamaya geçecek."
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        "$" + value.formatted(.number.precision(.fractionLength(2)))
    }

    private var primaryRecommendation: TrainingRecommendation? {
        env.training.primaryRecommendation(
            for: BrainContext(
                queueDepth: env.storage.queueDepth(),
                retryRate: env.sync.retryRate(),
                estimatedPnL: env.bot.estimatedPnL(currentPrice: env.market.last?.price),
                activeOrders: env.bot.activeOrders.count,
                usesSimulation: env.runtimeUsesSimulation,
                isAuthenticated: env.settings.isAuthenticated,
                selectedSymbol: env.settings.selectedSymbol,
                isCopyTradeActive: isCopyTradeActive
            )
        )
    }
}

private struct DashboardHeroCard: View {
    let partnerName: String
    let brandLogo: String
    let brandColor: Color
    let isPaperTrading: Bool
    let isAuthenticated: Bool
    let lastSync: Date?
    let advice: String
    let selectedSymbol: String
    let dcaAmount: Double
    let dcaPeriodSec: Int

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: brandLogo)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(brandColor)
                        .frame(width: 48, height: 48)
                        .background(brandColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: QAITheme.compactInnerCornerRadius, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(partnerName.uppercased())
                            .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                            .tracking(1.6)
                            .foregroundStyle(QAITheme.textPrimary)
                        Text("Mission Control")
                            .font(QAITheme.bodyFont)
                            .foregroundStyle(QAITheme.textSecondary)
                    }
                    Spacer()
                    AppMarkView(size: 42)
                }

                Text(advice)
                    .font(QAITheme.emphasisFont)
                    .foregroundStyle(QAITheme.textPrimary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        DashboardBadge(
                            title: isPaperTrading ? "Durum Simülasyon" : "Durum Aktif",
                            color: isPaperTrading ? QAITheme.warning : QAITheme.success
                        )
                        DashboardBadge(
                            title: isAuthenticated ? "Ağ Enterprise" : "Ağ Demo",
                            color: isAuthenticated ? QAITheme.accent : QAITheme.surfaceMuted
                        )
                        DashboardBadge(title: "Çifti \(selectedSymbol)", color: QAITheme.panelBlue)
                        DashboardBadge(title: "DCA \(Int(dcaAmount))$ / \(dcaPeriodSec)s", color: QAITheme.accentSoft)
                        DashboardBadge(title: "SLO %99.95", color: QAITheme.surfaceMuted)
                    }
                }

                Text("Senkron: \(relativeSyncText(lastSync))")
                    .font(QAITheme.captionFont)
                    .foregroundStyle(QAITheme.textSecondary)
            }
        }
    }

    private func relativeSyncText(_ date: Date?) -> String {
        guard let date else { return "henüz yok" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

private struct MarketPulseCard: View {
    @ObservedObject var market: MarketDataService
    @ObservedObject var watchlist: WatchlistService
    let selectedSymbol: String
    let chartData: [PnLData]
    let baselinePrice: Double?
    let onSelectSymbol: (String) -> Void

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Canlı Piyasa")
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .foregroundStyle(QAITheme.textPrimary)
                        Text(selectedSymbol)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(QAITheme.textSecondary)
                        Text("\(market.sourceText) • \(market.statusText)")
                            .font(.caption)
                            .foregroundStyle(market.lastError == nil ? QAITheme.accent : QAITheme.warning)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(priceText)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(QAITheme.textPrimary)
                        Text(changeText)
                            .font(.caption)
                            .foregroundStyle(changeColor)
                    }
                }

                if let lastError = market.lastError, !lastError.isEmpty {
                    Text(lastError)
                        .font(.caption)
                        .foregroundStyle(QAITheme.warning)
                }

                PnLChartView(data: chartData)
                    .frame(height: 150)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(watchlist.items, id: \.self) { symbol in
                            Button {
                                onSelectSymbol(symbol)
                            } label: {
                                Text(symbol)
                                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                                    .foregroundStyle(symbol == selectedSymbol ? QAITheme.background : QAITheme.textPrimary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(symbol == selectedSymbol ? QAITheme.accent : QAITheme.surfaceMuted.opacity(0.65))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var priceText: String {
        guard let tick = market.last else { return "Bağlanıyor..." }
        return "$" + tick.price.formatted(.number.precision(.fractionLength(2)))
    }

    private var changeText: String {
        guard let tick = market.last, let baselinePrice else { return "Akış bekleniyor" }
        let delta = tick.price - baselinePrice
        let percent = baselinePrice == 0 ? 0 : (delta / baselinePrice) * 100
        return String(format: "%@%.2f%%", percent >= 0 ? "+" : "", percent)
    }

    private var changeColor: Color {
        guard let tick = market.last, let baselinePrice else { return QAITheme.textSecondary }
        return tick.price >= baselinePrice ? QAITheme.success : QAITheme.error
    }
}

private struct OperationsMenuCard: View {
    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                Label("Operasyon Menüsü", systemImage: "square.grid.2x2")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(QAITheme.textPrimary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    NavigationLink { MarketBridgeView() } label: {
                        OperationsMenuTile(title: "Market Bridge", icon: "globe", tint: QAITheme.panelBlue)
                    }
                    .buttonStyle(.plain)
                    NavigationLink { IntelligenceCenterView() } label: {
                        OperationsMenuTile(title: "Beyin", icon: "brain.head.profile", tint: QAITheme.success)
                    }
                    .buttonStyle(.plain)
                    NavigationLink { StrategyLibraryView() } label: {
                        OperationsMenuTile(title: "Preset", icon: "bolt.horizontal.circle", tint: QAITheme.accent)
                    }
                    .buttonStyle(.plain)
                    NavigationLink { RunbookCenterView() } label: {
                        OperationsMenuTile(title: "Runbook", icon: "list.bullet.clipboard", tint: QAITheme.warning)
                    }
                    .buttonStyle(.plain)
                    NavigationLink { TrainingDocumentViewer() } label: {
                        OperationsMenuTile(title: "Test & Demo", icon: "play.rectangle", tint: QAITheme.surfaceMuted)
                    }
                    .buttonStyle(.plain)
                    NavigationLink { SettingsView() } label: {
                        OperationsMenuTile(title: "Ayarlar", icon: "slider.horizontal.3", tint: QAITheme.accentSoft)
                    }
                    .buttonStyle(.plain)
                    NavigationLink { SimulationsHubView() } label: {
                        OperationsMenuTile(title: "Sim Stack", icon: "square.stack.3d.up", tint: Color.cyan)
                    }
                    .buttonStyle(.plain)
                    NavigationLink { HQAdminView() } label: {
                        OperationsMenuTile(title: "HQ Admin", icon: "shield.lefthalf.filled", tint: QAITheme.error)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct LiveBridgeCalloutCard: View {
    let snapshot: CoinMarketSnapshot?
    let isEnabled: Bool
    let lastError: String?

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("CoinMarketCap Köprüsü", systemImage: "network")
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundStyle(QAITheme.textPrimary)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .foregroundStyle(QAITheme.accent)
                }

                if let lastError, !lastError.isEmpty {
                    Text(lastError)
                        .font(.subheadline)
                        .foregroundStyle(QAITheme.warning)
                } else if let snapshot {
                    Text("\(snapshot.assetName) için canlı market özeti hazır. Price, rank, market cap ve hacim detayları bridge ekranında.")
                        .font(.subheadline)
                        .foregroundStyle(QAITheme.textSecondary)
                    HStack(spacing: 10) {
                        SnapshotTile(title: "Fiyat", value: "$" + snapshot.priceUSD.formatted(.number.precision(.fractionLength(2))), tint: QAITheme.accent)
                        SnapshotTile(title: "Rank", value: snapshot.rank.map { "#\($0)" } ?? "—", tint: QAITheme.panelBlue)
                    }
                } else {
                    Text(isEnabled ? "Köprü açıldı, ilk CoinMarketCap snapshot bekleniyor." : "Ayarlar ekranından CoinMarketCap köprüsünü açabilirsiniz.")
                        .font(.subheadline)
                        .foregroundStyle(QAITheme.textSecondary)
                }
            }
        }
    }
}

private struct PortfolioSnapshotCard: View {
    let estimatedPnL: Double
    let exposure: Double
    let activeStrategies: Int
    let queueDepth: Int
    let retryRate: Double

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                Label("Portföy Snapshot", systemImage: "chart.bar.xaxis")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(QAITheme.textPrimary)

                HStack(spacing: 10) {
                    SnapshotTile(title: "Tahmini PnL", value: String(format: "%@%.2f", estimatedPnL >= 0 ? "+" : "", estimatedPnL), tint: estimatedPnL >= 0 ? QAITheme.success : QAITheme.error)
                    SnapshotTile(title: "Maruziyet", value: String(format: "$%.0f", exposure), tint: QAITheme.accent)
                }

                HStack(spacing: 10) {
                    SnapshotTile(title: "Strateji", value: "\(activeStrategies)", tint: QAITheme.surfaceMuted)
                    SnapshotTile(title: "Retry", value: "\(Int(retryRate * 100))%", tint: retryRate > 0.25 ? QAITheme.warning : QAITheme.success)
                    SnapshotTile(title: "Outbox", value: "\(queueDepth)", tint: QAITheme.warning)
                }
            }
        }
    }
}

private struct IntelligenceCard: View {
    let status: String
    let aiAdvice: String
    let isLicensed: Bool
    let activeSymbol: String

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                Label("AI Analist Tavsiyesi", systemImage: "brain.head.profile")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(QAITheme.accent)

                Text(aiAdvice)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(QAITheme.textPrimary)

                HStack(spacing: 10) {
                    DashboardBadge(title: activeSymbol, color: QAITheme.surfaceMuted)
                    DashboardBadge(title: isLicensed ? "Premium" : "Demo", color: isLicensed ? QAITheme.success : QAITheme.warning)
                    Spacer()
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(QAITheme.textSecondary)
                }
            }
        }
    }
}

private struct OperationsHealthCard: View {
    @ObservedObject var health: HealthPanelModel
    @ObservedObject var hq: GlobalSinirSistemi
    let isPaperTrading: Bool

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                Label("Operasyon Sağlığı", systemImage: "waveform.path.ecg")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(QAITheme.textPrimary)

                HStack(spacing: 10) {
                    SnapshotTile(title: "P95", value: "\(Int(health.p95LatencyMs)) ms", tint: QAITheme.success)
                    SnapshotTile(title: "Drop", value: "\(health.duplicateDrops)", tint: QAITheme.error)
                    SnapshotTile(title: "HQ", value: hq.hqBaglantiDurumu ? "Online" : "Offline", tint: hq.hqBaglantiDurumu ? QAITheme.success : QAITheme.error)
                }

                Text(isPaperTrading ? "Güvenli simülasyon kanalında çalışıyor." : "Canlı adapter hattı aktif.")
                    .font(.subheadline)
                    .foregroundStyle(QAITheme.textSecondary)
            }
        }
    }
}

private struct DashboardActionsCard: View {
    let queueDepth: Int
    let dcaAmount: Double
    let gridSteps: Int
    let copyRatio: Double
    let isDCAActive: Bool
    let isGridActive: Bool
    let isCopyTradeActive: Bool
    let onStartDCA: () -> Void
    let onStartGrid: () -> Void
    let onToggleCopyTrade: () -> Void
    let onExportCSV: () -> Void
    let onClearOutbox: () -> Void
    let onPanicStop: () -> Void

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                Label("Komuta Butonları", systemImage: "bolt.fill")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(QAITheme.textPrimary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    DashboardActionButton(
                        title: isDCAActive ? "DCA Aktif" : "DCA Başlat",
                        subtitle: "$\(Int(dcaAmount))",
                        tint: QAITheme.accent,
                        isDisabled: isDCAActive,
                        action: onStartDCA
                    )
                    DashboardActionButton(
                        title: isGridActive ? "Grid Aktif" : "Grid Kur",
                        subtitle: "\(gridSteps) kademe",
                        tint: QAITheme.success,
                        isDisabled: isGridActive,
                        action: onStartGrid
                    )
                    DashboardActionButton(
                        title: isCopyTradeActive ? "Kopya Durdur" : "Kopya Başlat",
                        subtitle: String(format: "%.2fx", copyRatio),
                        tint: isCopyTradeActive ? QAITheme.warning : QAITheme.surfaceMuted,
                        action: onToggleCopyTrade
                    )
                    DashboardActionButton(
                        title: "CSV Al",
                        subtitle: "orders.csv",
                        tint: QAITheme.surfaceMuted,
                        action: onExportCSV
                    )
                    DashboardActionButton(
                        title: "Outbox Temizle",
                        subtitle: "\(queueDepth) bekleyen",
                        tint: QAITheme.warning,
                        action: onClearOutbox
                    )
                    DashboardActionButton(
                        title: "Panik Stop",
                        subtitle: "Tüm botlar",
                        tint: QAITheme.error,
                        action: onPanicStop
                    )
                }
            }
        }
    }
}

private struct KnowledgeHubCard: View {
    let recommendation: TrainingRecommendation?

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                Label("Beyin ve Strateji", systemImage: "brain")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(QAITheme.textPrimary)

                if let recommendation {
                    Text(recommendation.title)
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundStyle(QAITheme.accent)
                    Text(recommendation.summary)
                        .font(.subheadline)
                        .foregroundStyle(QAITheme.textSecondary)
                } else {
                    Text("Eğitim kaynağı yükleniyor.")
                        .font(.subheadline)
                        .foregroundStyle(QAITheme.textSecondary)
                }

                HStack(spacing: 10) {
                    NavigationLink {
                        IntelligenceCenterView()
                    } label: {
                        KnowledgeHubButton(title: "Beyin Merkezi", tint: QAITheme.accent, usesDarkForeground: true)
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        StrategyLibraryView()
                    } label: {
                        KnowledgeHubButton(title: "Presetler", tint: QAITheme.surfaceMuted, usesDarkForeground: false)
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        RunbookCenterView()
                    } label: {
                        KnowledgeHubButton(title: "Runbook", tint: QAITheme.warning, usesDarkForeground: true)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct ActiveOrdersCard: View {
    @ObservedObject var bot: BotService

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Aktif Emirler", systemImage: "list.bullet.rectangle")
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundStyle(QAITheme.textPrimary)
                    Spacer()
                    NavigationLink {
                        OrdersView()
                    } label: {
                        Text("Tümünü Aç")
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .foregroundStyle(QAITheme.accent)
                    }
                }

                if bot.activeOrders.isEmpty {
                    Text("Henüz aktif emir yok. Yukarıdaki komuta butonları ile strateji başlatabilirsiniz.")
                        .font(.subheadline)
                        .foregroundStyle(QAITheme.textSecondary)
                } else {
                    ForEach(bot.activeOrders.prefix(4)) { order in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(order.side == "GRID" ? QAITheme.success : QAITheme.accent)
                                .frame(width: 10, height: 10)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(order.symbol)
                                    .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                                    .foregroundStyle(QAITheme.textPrimary)
                                Text(order.side)
                                    .font(.caption)
                                    .foregroundStyle(QAITheme.textSecondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(String(format: "$%.2f", order.price))
                                    .font(.system(.subheadline, design: .monospaced))
                                    .foregroundStyle(QAITheme.textPrimary)
                                Text(String(format: "%.4f", order.amount))
                                    .font(.caption)
                                    .foregroundStyle(QAITheme.textSecondary)
                            }
                        }
                        .padding(14)
                        .background(QAITheme.surfaceMuted.opacity(0.45))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
            }
        }
    }
}

private struct OperationsMenuTile: View {
    let title: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
            Text(title)
                .font(QAITheme.captionFont)
                .lineLimit(2)
        }
        .foregroundStyle(QAITheme.textPrimary)
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
        .padding(11)
        .background(tint.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: QAITheme.compactInnerCornerRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: QAITheme.compactInnerCornerRadius, style: .continuous))
    }
}

private struct SnapshotTile: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(QAITheme.captionFont)
                .foregroundStyle(QAITheme.textSecondary)
            Text(value)
                .font(QAITheme.metricFont)
                .foregroundStyle(QAITheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: QAITheme.compactInnerCornerRadius, style: .continuous))
    }
}

private struct KnowledgeHubButton: View {
    let title: String
    let tint: Color
    let usesDarkForeground: Bool

    var body: some View {
        Text(title)
            .font(QAITheme.buttonFont)
            .foregroundStyle(usesDarkForeground ? QAITheme.background : QAITheme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, QAITheme.compactButtonVerticalPadding)
            .background(tint)
            .clipShape(RoundedRectangle(cornerRadius: QAITheme.compactInnerCornerRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: QAITheme.compactInnerCornerRadius, style: .continuous))
    }
}

private struct DashboardBadge: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(QAITheme.captionFont.weight(.semibold))
            .foregroundStyle(QAITheme.textPrimary)
            .padding(.horizontal, QAITheme.compactChipHorizontalPadding)
            .padding(.vertical, QAITheme.compactChipVerticalPadding)
            .background(color.opacity(0.16))
            .clipShape(Capsule())
    }
}

private struct DashboardActionButton: View {
    let title: String
    let subtitle: String
    let tint: Color
    let isDisabled: Bool
    let action: () -> Void

    init(title: String, subtitle: String, tint: Color, isDisabled: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.tint = tint
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(isDisabled ? QAITheme.textSecondary : QAITheme.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(isDisabled ? QAITheme.textSecondary : QAITheme.textPrimary.opacity(0.86))
            }
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .padding(14)
            .background(isDisabled ? QAITheme.surfaceMuted : tint)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .disabled(isDisabled)
        .buttonStyle(.plain)
        .opacity(isDisabled ? 0.7 : 1)
    }
}

public struct BursaHQLogo: View {
    public init() {}

    public var body: some View {
        ZStack {
            Circle().stroke(QAITheme.success.opacity(0.28), lineWidth: 2)
            Image(systemName: "hexagon.fill").foregroundColor(QAITheme.success)
            Text("B")
                .font(.system(size: 14, weight: .black))
                .foregroundColor(.black)
        }
    }
}
