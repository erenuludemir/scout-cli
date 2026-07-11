import Foundation
import Combine
import OSLog
#if canImport(TipKit)
import TipKit
#endif

@MainActor
public final class AppEnvironment: ObservableObject {
    public enum LaunchControl {
        private static let arguments = Set(ProcessInfo.processInfo.arguments)

        public static var isUITesting: Bool {
            arguments.contains("-ui-testing")
        }

        public static var usesStaticRuntime: Bool {
            arguments.contains("-ui-testing-static-runtime")
        }
    }

    private struct RuntimeSettingsSnapshot: Equatable {
        let usesSimulation: Bool
        let symbol: String
        let marketBridgeEnabled: Bool
    }

    @Published public var settings: SettingsStore
    public let storage: StorageService
    public let wallet: WalletService
    public let walletPortfolio: WalletPortfolioService
    public let market: MarketDataService
    public let bot: BotService
    public let alerts: AlertService
    public let sync: SyncClient
    public let metrics: MetricsCenter
    public let audit: AuditService
    public let health: HealthPanelModel
    public let copyTrade: CopyTradeService
    public let watchlist: WatchlistService
    public let training: TrainingGuideStore
    public let trainingJourney: TrainingJourneyStore
    public let marketBridge: CoinMarketCapBridgeService
    public let walletActivation: WalletActivationStore
    public let simulations: SimulationControlCenter
    public let runtimeMetrics: RuntimeMetricsRegistry
    public let runtimeAdmin: RuntimeAdminMonitor
    public lazy var remoteMonitor: RemoteMonitor = RemoteMonitor(env: self)
    private var hasBootstrapped = false
    private var runtimeSettingsApplyPending = false
    private var appliedRuntimeSettings: RuntimeSettingsSnapshot?
    private var forwardedObjectChangeCancellables = Set<AnyCancellable>()
    private var forwardedObjectChangePending = false
    private static var hasConfiguredTipKit = false

    public static func liveInSim() -> AppEnvironment {
        let flags = FeatureFlags.load()
        let settings = SettingsStore(flags: flags)
        if LaunchControl.usesStaticRuntime {
            settings.isPaperTrading = true
            settings.liveAdapters = false
            settings.marketBridgeEnabled = false
            settings.telemetryEnabled = false
            settings.selectedSymbol = "BTCUSDT"
        }
        let storage = StorageService()
        let audit = AuditService(storage: storage)
        let metrics = MetricsCenter()
        let runtimeMetrics = RuntimeMetricsRegistry()
        let wallet = WalletService(storage: storage, audit: audit)
        let walletPortfolio = WalletPortfolioService()
        let market = MarketDataService(metrics: metrics, runtimeMetrics: runtimeMetrics)
        let bot = BotService(market: market, storage: storage, audit: audit, metrics: metrics)
        let alerts = AlertService(market: market, metrics: metrics)
        let sync = SyncClient(storage: storage, metrics: metrics, audit: audit)
        let copyTrade = CopyTradeService(market: market, storage: storage, audit: audit, metrics: metrics)
        let health = HealthPanelModel(storage: storage, metrics: metrics, sync: sync, market: market)
        let watchlist = WatchlistService()
        let training = TrainingGuideStore()
        let trainingJourney = TrainingJourneyStore()
        let marketBridge = CoinMarketCapBridgeService()
        let walletActivation = WalletActivationStore()
        let simulations = SimulationControlCenter.shared
        let runtimeAdmin = RuntimeAdminMonitor()
        simulations.applyFeatureFlags(flags)
        
        return AppEnvironment(
            settings: settings,
            storage: storage,
            wallet: wallet,
            walletPortfolio: walletPortfolio,
            market: market,
            bot: bot,
            alerts: alerts,
            sync: sync,
            metrics: metrics,
            audit: audit,
            health: health,
            copyTrade: copyTrade,
            watchlist: watchlist,
            training: training,
            trainingJourney: trainingJourney,
            marketBridge: marketBridge,
            walletActivation: walletActivation,
            simulations: simulations,
            runtimeMetrics: runtimeMetrics,
            runtimeAdmin: runtimeAdmin
        )
    }

    public init(settings: SettingsStore, storage: StorageService, wallet: WalletService, walletPortfolio: WalletPortfolioService, market: MarketDataService, bot: BotService, alerts: AlertService, sync: SyncClient, metrics: MetricsCenter, audit: AuditService, health: HealthPanelModel, copyTrade: CopyTradeService, watchlist: WatchlistService, training: TrainingGuideStore, trainingJourney: TrainingJourneyStore, marketBridge: CoinMarketCapBridgeService, walletActivation: WalletActivationStore, simulations: SimulationControlCenter, runtimeMetrics: RuntimeMetricsRegistry, runtimeAdmin: RuntimeAdminMonitor) {
        self.settings = settings
        self.storage = storage
        self.wallet = wallet
        self.walletPortfolio = walletPortfolio
        self.market = market
        self.bot = bot
        self.alerts = alerts
        self.sync = sync
        self.metrics = metrics
        self.audit = audit
        self.health = health
        self.copyTrade = copyTrade
        self.watchlist = watchlist
        self.training = training
        self.trainingJourney = trainingJourney
        self.marketBridge = marketBridge
        self.walletActivation = walletActivation
        self.simulations = simulations
        self.runtimeMetrics = runtimeMetrics
        self.runtimeAdmin = runtimeAdmin
        bindChildObjectChanges()
        bindAutonomyControlCenter()
    }

    public func bootstrap() async {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        let interval: Any? = {
            if #available(iOS 15.0, macOS 12.0, *) {
                return QAISignpost.begin("App Bootstrap")
            }
            return nil
        }()
        // Ağır işler ilk frame sonrasına itiliyor
        if Self.LaunchControl.isUITesting {
            runtimeMetrics.recordLaunch()
            applyRuntimeSettings()
            if #available(iOS 15.0, macOS 12.0, *), let interval = interval as? OSSignpostIntervalState {
                QAISignpost.end("App Bootstrap", interval)
            }
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            try? self.wallet.ensureKeypair()
        }

        // Eğitim verilerini düşük öncelikle yükle
        training.loadIfNeeded(priority: .background)

        // UI tarafındaki konfigürasyonları bir sonraki runloop'a ertele
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.runtimeMetrics.recordLaunch()
            self.configureTipKitIfNeeded()
            self.applyRuntimeSettings()
            self.walletPortfolio.startIfNeeded(
                selectedNetworkID: self.settings.selectedWalletNetworkID,
                walletService: self.wallet,
                networks: self.wallet.supportedNetworks()
            )
            self.health.bind()
            self.simulations.bootstrap()
            self.runtimeAdmin.startIfNeeded()
            _ = self.remoteMonitor
            AutonomyControlCenter.shared.refresh(
                runtimeMetrics: self.runtimeMetrics,
                portfolio: self.walletPortfolio
            )
            if #available(iOS 15.0, macOS 12.0, *), let interval = interval as? OSSignpostIntervalState {
                QAISignpost.end("App Bootstrap", interval)
            }
        }
    }

    public func applyRuntimeSettings() {
        guard !runtimeSettingsApplyPending else { return }
        runtimeSettingsApplyPending = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.runtimeSettingsApplyPending = false
            self.applyRuntimeSettingsNow()
        }
    }

    public var runtimeUsesSimulation: Bool {
        settings.isPaperTrading || !settings.liveAdapters
    }

    public func applyPreset(_ preset: StrategyPreset) {
        let anchorPrice = market.last?.price ?? 50_000
        settings.dcaAmount = preset.dcaAmount
        settings.dcaPeriodSec = preset.dcaPeriodSec
        settings.gridLower = anchorPrice * (1 - preset.gridBandLowerRatio)
        settings.gridUpper = anchorPrice * (1 + preset.gridBandUpperRatio)
        settings.gridSteps = preset.gridSteps
        settings.copyRatio = preset.copyRatio
        settings.shockThreshold = preset.shockThreshold
        settings.isPaperTrading = preset.prefersSimulation
        settings.liveAdapters = !preset.prefersSimulation
        if let symbol = preset.preferredSymbol {
            settings.selectedSymbol = symbol
        }
        applyRuntimeSettings()
        if #available(iOS 15.0, macOS 12.0, *) {
            QAISignpost.event("Strategy Preset Applied", message: "preset=\(preset.id)")
        }
    }

    private func applyRuntimeSettingsNow() {
        let normalizedSymbol = MarketDataService.normalizedSymbol(settings.selectedSymbol)
        if settings.selectedSymbol != normalizedSymbol {
            settings.selectedSymbol = normalizedSymbol
        }

        let snapshot = RuntimeSettingsSnapshot(
            usesSimulation: runtimeUsesSimulation,
            symbol: normalizedSymbol,
            marketBridgeEnabled: settings.marketBridgeEnabled
        )

        if let appliedRuntimeSettings {
            if appliedRuntimeSettings.usesSimulation != snapshot.usesSimulation || appliedRuntimeSettings.symbol != snapshot.symbol {
                market.reconfigure(simMode: snapshot.usesSimulation, symbol: snapshot.symbol)
            }
        } else {
            market.startIfNeeded(simMode: snapshot.usesSimulation, symbol: snapshot.symbol)
        }

        if snapshot.marketBridgeEnabled {
            if appliedRuntimeSettings?.marketBridgeEnabled != true || appliedRuntimeSettings?.symbol != snapshot.symbol {
                marketBridge.reconfigure(symbol: snapshot.symbol)
            }
        } else {
            if appliedRuntimeSettings?.marketBridgeEnabled != false {
                marketBridge.stop()
            }
        }

        walletPortfolio.reconfigure(
            selectedNetworkID: settings.selectedWalletNetworkID,
            walletService: wallet,
            networks: wallet.supportedNetworks()
        )

        appliedRuntimeSettings = snapshot
    }

    private func configureTipKitIfNeeded() {
        #if canImport(TipKit)
        guard !Self.hasConfiguredTipKit else { return }
        do {
            try Tips.configure([
                .displayFrequency(.immediate)
            ])
        } catch {
            metrics.recordError("tipkit_config_failed=\(error.localizedDescription)")
        }
        Self.hasConfiguredTipKit = true
        #endif
    }

    private func bindChildObjectChanges() {
        forwardedObjectChangeCancellables.removeAll()
        forwardedObjectChangePending = false

        forwardObjectChanges(from: settings)
        forwardObjectChanges(from: storage)
        forwardObjectChanges(from: walletPortfolio)
        forwardObjectChanges(from: market)
        forwardObjectChanges(from: bot)
        forwardObjectChanges(from: alerts)
        forwardObjectChanges(from: health)
        forwardObjectChanges(from: copyTrade)
        forwardObjectChanges(from: watchlist)
        forwardObjectChanges(from: training)
        forwardObjectChanges(from: trainingJourney)
        forwardObjectChanges(from: marketBridge)
        forwardObjectChanges(from: walletActivation)
        forwardObjectChanges(from: simulations)
        forwardObjectChanges(from: runtimeMetrics)
        forwardObjectChanges(from: runtimeAdmin)
    }

    private func forwardObjectChanges<Object: ObservableObject>(from object: Object) {
        object.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.scheduleForwardedObjectChange()
            }
            .store(in: &forwardedObjectChangeCancellables)
    }

    private func scheduleForwardedObjectChange() {
        guard !forwardedObjectChangePending else { return }
        forwardedObjectChangePending = true

        Task { @MainActor [weak self] in
            await Task.yield()
            guard let self else { return }
            self.forwardedObjectChangePending = false
            self.objectWillChange.send()
        }
    }

    private func bindAutonomyControlCenter() {
        let autonomy = AutonomyControlCenter.shared
        let refreshAutonomy: () -> Void = { [weak self] in
            guard let self else { return }
            autonomy.refresh(
                runtimeMetrics: self.runtimeMetrics,
                portfolio: self.walletPortfolio
            )
        }

        walletPortfolio.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { _ in refreshAutonomy() }
            .store(in: &forwardedObjectChangeCancellables)

        runtimeMetrics.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { _ in refreshAutonomy() }
            .store(in: &forwardedObjectChangeCancellables)

        CognitiveTwinRegistry.shared.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { _ in refreshAutonomy() }
            .store(in: &forwardedObjectChangeCancellables)

        BarakfakihCitadel.shared.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { _ in refreshAutonomy() }
            .store(in: &forwardedObjectChangeCancellables)

        TelepathyGateway.shared.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { _ in refreshAutonomy() }
            .store(in: &forwardedObjectChangeCancellables)
    }
}
