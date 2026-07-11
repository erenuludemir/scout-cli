import Foundation
import Combine

private enum MarketDataDefaults {
    static let symbol = "BTCUSDT"
}

@MainActor
public final class MarketDataService: ObservableObject {
    private enum LiveState: Equatable {
        case idle
        case starting(symbol: String)
        case live(symbol: String)
        case coolingDown(symbol: String, until: Date)
    }

    @Published public private(set) var last: Tick?
    @Published public private(set) var sourceText = "Simülasyon"
    @Published public private(set) var statusText = "Hazır"
    @Published public private(set) var lastError: String?

    private let metrics: MetricsCenter
    private let runtimeMetrics: RuntimeMetricsRegistry?
    private let session: URLSession

    private var started = false
    private var binanceAdapter: BinanceAdapter?
    private var simTask: Task<Void, Never>?
    private var liveFallbackTask: Task<Void, Never>?
    private var liveReconnectTask: Task<Void, Never>?
    private var liveWarmupTask: Task<Void, Never>?

    private var currentModeIsSim = true
    private var currentSymbol = MarketDataDefaults.symbol
    private var isSceneActive = true

    private var lastWebSocketTickAt: Date?
    private var lastPublishedLiveTickAt: Date?
    private var websocketFailureCount = 0
    private var websocketCooldownUntil: Date?

    private var liveState: LiveState = .idle
    private var activeLiveConnectionID: UUID?

    public init(
        metrics: MetricsCenter,
        runtimeMetrics: RuntimeMetricsRegistry? = nil,
        session: URLSession = .shared
    ) {
        self.metrics = metrics
        self.runtimeMetrics = runtimeMetrics
        self.session = session
    }

    static func normalizedSymbol(_ symbol: String) -> String {
        let cleaned = symbol
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .filter { $0.isLetter || $0.isNumber }

        return cleaned.isEmpty ? MarketDataDefaults.symbol : cleaned
    }

    public func startIfNeeded(simMode: Bool, symbol: String = "BTCUSDT") {
        guard !started else { return }
        configure(simMode: simMode, symbol: Self.normalizedSymbol(symbol))
    }

    public func reconfigure(simMode: Bool, symbol: String = "BTCUSDT") {
        let normalizedSymbol = Self.normalizedSymbol(symbol)

        guard started else {
            configure(simMode: simMode, symbol: normalizedSymbol)
            return
        }

        if currentModeIsSim == simMode && currentSymbol == normalizedSymbol {
            if simMode {
                if simTask != nil { return }
            } else {
                switch liveState {
                case .starting(let running) where running == normalizedSymbol:
                    return
                case .live(let running) where running == normalizedSymbol && binanceAdapter != nil:
                    return
                case .coolingDown(let running, let until) where running == normalizedSymbol && until > .now:
                    return
                default:
                    break
                }
            }
        }

        stopAll()
        configure(simMode: simMode, symbol: normalizedSymbol)
    }

    private func configure(simMode: Bool, symbol: String) {
        started = true
        currentModeIsSim = simMode
        currentSymbol = symbol
        isSceneActive = true

        lastError = nil
        lastWebSocketTickAt = nil
        lastPublishedLiveTickAt = nil
        websocketFailureCount = 0
        websocketCooldownUntil = nil
        liveState = .idle
        activeLiveConnectionID = nil

        if simMode {
            startSim(symbol: symbol)
        } else {
            startLive(symbol: symbol)
        }
    }

    private func startSim(symbol: String) {
        guard isSceneActive else {
            publish { store in
                store.sourceText = "Simülasyon"
                store.statusText = "Duraklatıldı"
            }
            return
        }

        liveReconnectTask?.cancel()
        liveReconnectTask = nil

        liveWarmupTask?.cancel()
        liveWarmupTask = nil

        liveFallbackTask?.cancel()
        liveFallbackTask = nil

        binanceAdapter?.disconnect()
        binanceAdapter = nil

        activeLiveConnectionID = nil
        liveState = .idle

        simTask?.cancel()
        simTask = Task { [weak self] in
            guard let self else { return }

            await MainActor.run {
                self.publish { store in
                    store.sourceText = "Simülasyon"
                    store.statusText = "Otomatik"
                    store.lastError = nil
                }
            }

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }

                await MainActor.run {
                    guard self.started, self.currentModeIsSim, self.currentSymbol == symbol else { return }
                    let tick = self.makeSimulatedTick(for: symbol)
                    self.applySimulatedTick(tick)
                }
            }
        }
    }

    private func startLive(symbol: String) {
        guard started, !currentModeIsSim, currentSymbol == symbol, isSceneActive else { return }

        switch liveState {
        case .starting(let running) where running == symbol:
            return
        case .live(let running) where running == symbol && binanceAdapter != nil:
            return
        case .coolingDown(let running, let until) where running == symbol && until > .now:
            let remaining = max(Int(until.timeIntervalSinceNow.rounded(.up)), 1)
            publish { store in
                store.sourceText = "Binance REST"
                store.statusText = "Yedek mod"
                store.lastError = "Websocket geçici olarak duraklatıldı. \(remaining) sn sonra yeniden denenecek."
            }
            scheduleReconnect(symbol: symbol, delay: until.timeIntervalSinceNow)
            return
        default:
            break
        }

        simTask?.cancel()
        simTask = nil

        liveReconnectTask?.cancel()
        liveReconnectTask = nil

        liveWarmupTask?.cancel()
        liveWarmupTask = nil

        binanceAdapter?.disconnect()
        binanceAdapter = nil
        activeLiveConnectionID = nil

        if let cooldownUntil = websocketCooldownUntil, cooldownUntil > .now {
            let remaining = max(Int(cooldownUntil.timeIntervalSinceNow.rounded(.up)), 1)
            liveState = .coolingDown(symbol: symbol, until: cooldownUntil)
            publish { store in
                store.sourceText = "Binance REST"
                store.statusText = "Yedek mod"
                store.lastError = "Websocket geçici olarak duraklatıldı. \(remaining) sn sonra yeniden denenecek."
            }
            scheduleReconnect(symbol: symbol, delay: cooldownUntil.timeIntervalSinceNow)
            return
        }

        liveState = .starting(symbol: symbol)
        publish { store in
            store.sourceText = "Binance WS"
            store.statusText = "Bağlanıyor"
            store.lastError = nil
        }

        let endpoint = preferredEndpoint()
        let connectionID = UUID()
        activeLiveConnectionID = connectionID

        let adapter = BinanceAdapter(
            symbol: symbol,
            endpoint: endpoint
        ) { [weak self] tick in
            Task { @MainActor [weak self] in
                self?.handleLiveTick(tick, connectionID: connectionID)
            }
        } onDisconnect: { [weak self] reason in
            Task { @MainActor [weak self] in
                self?.handleLiveDisconnect(symbol: symbol, reason: reason, connectionID: connectionID)
            }
        }

        binanceAdapter = adapter
        adapter.connect()
        liveState = .live(symbol: symbol)

        scheduleInitialFallbackProbe(symbol: symbol)
        startFallbackWatchdog(symbol: symbol)
    }

    public func stopAll(clearLastTick: Bool = true) {
        simTask?.cancel()
        simTask = nil

        liveFallbackTask?.cancel()
        liveFallbackTask = nil

        liveReconnectTask?.cancel()
        liveReconnectTask = nil

        liveWarmupTask?.cancel()
        liveWarmupTask = nil

        binanceAdapter?.disconnect()
        binanceAdapter = nil

        activeLiveConnectionID = nil
        lastWebSocketTickAt = nil
        lastPublishedLiveTickAt = nil
        websocketFailureCount = 0
        websocketCooldownUntil = nil
        liveState = .idle

        publish { store in
            if clearLastTick {
                store.last = nil
            }
            store.lastError = nil
            store.sourceText = store.currentModeIsSim ? "Simülasyon" : "Binance"
            store.statusText = "Durduruldu"
        }

        started = false
        isSceneActive = true
    }

    public func pauseForInactiveScene() {
        guard started else { return }

        isSceneActive = false
        simTask?.cancel()
        simTask = nil
        liveFallbackTask?.cancel()
        liveFallbackTask = nil
        liveReconnectTask?.cancel()
        liveReconnectTask = nil
        liveWarmupTask?.cancel()
        liveWarmupTask = nil

        if !currentModeIsSim {
            binanceAdapter?.disconnect()
            binanceAdapter = nil
            activeLiveConnectionID = nil
            liveState = .idle
        }

        publish { store in
            store.statusText = "Duraklatıldı"
            if !store.currentModeIsSim {
                store.sourceText = "Canlı akış"
            }
        }
    }

    public func refreshForActiveScene() {
        guard started else { return }
        isSceneActive = true

        if currentModeIsSim {
            if simTask == nil {
                startSim(symbol: currentSymbol)
            } else {
                publish { store in
                    store.sourceText = "Simülasyon"
                    store.statusText = "Otomatik"
                    store.lastError = nil
                }
            }
            return
        }

        if let cooldownUntil = websocketCooldownUntil, cooldownUntil > .now {
            liveState = .coolingDown(symbol: currentSymbol, until: cooldownUntil)
            scheduleReconnect(symbol: currentSymbol, delay: cooldownUntil.timeIntervalSinceNow)
            return
        }

        switch liveState {
        case .starting(let running) where running == currentSymbol:
            return
        case .live(let running) where running == currentSymbol && binanceAdapter != nil:
            publish { store in
                store.sourceText = "Binance WS"
                store.statusText = "Canlı"
                store.lastError = nil
            }
            return
        default:
            startLive(symbol: currentSymbol)
        }
    }

    deinit {
        simTask?.cancel()
        liveFallbackTask?.cancel()
        liveReconnectTask?.cancel()
        liveWarmupTask?.cancel()
        binanceAdapter?.disconnect()
    }

    private func basePrice(for symbol: String) -> Double {
        switch symbol {
        case "ETHUSDT":
            return 3_200
        case "BNBUSDT":
            return 620
        case "SOLUSDT":
            return 190
        default:
            return 50_000
        }
    }

    private func makeSimulatedTick(for symbol: String) -> Tick {
        let basePrice = basePrice(for: symbol)
        let volatility = symbol == "BTCUSDT" ? 0.0008 : 0.0014
        let newPrice = basePrice * (1 + Double.random(in: -volatility...volatility))
        return Tick(ts: .now, price: newPrice, vol: .random(in: 1...5))
    }

    private func applySimulatedTick(_ tick: Tick) {
        last = tick
        metrics.recordTick()
        runtimeMetrics?.recordSimTick()
        sourceText = "Simülasyon"
        statusText = "Otomatik"
        lastError = nil
    }

    private func handleLiveTick(_ tick: Tick, connectionID: UUID) {
        guard activeLiveConnectionID == connectionID else { return }
        guard started, !currentModeIsSim else { return }

        let now = Date()
        liveWarmupTask?.cancel()
        liveWarmupTask = nil
        lastWebSocketTickAt = tick.ts
        websocketFailureCount = 0
        websocketCooldownUntil = nil
        liveState = .live(symbol: currentSymbol)
        metrics.recordTick()
        runtimeMetrics?.recordLiveTick()

        // Websocket feeds can publish far faster than the UI can usefully render.
        // Downsampling the published tick stream keeps long debug sessions from
        // retaining excessive view-debugging state on device.
        if let lastPublishedLiveTickAt, now.timeIntervalSince(lastPublishedLiveTickAt) < 0.5 {
            return
        }

        lastPublishedLiveTickAt = now
        last = tick

        sourceText = "Binance WS"
        statusText = "Canlı"
        lastError = nil
    }

    private func handleLiveDisconnect(symbol: String, reason: String, connectionID: UUID) {
        guard activeLiveConnectionID == connectionID else { return }
        guard started, !currentModeIsSim, currentSymbol == symbol else { return }

        websocketFailureCount += 1
        let reconnectDelay = reconnectDelayForCurrentState()

        liveWarmupTask?.cancel()
        liveWarmupTask = nil

        binanceAdapter?.disconnect()
        binanceAdapter = nil
        activeLiveConnectionID = nil

        if websocketFailureCount >= 3 {
            let until = Date().addingTimeInterval(reconnectDelay)
            websocketCooldownUntil = until
            liveState = .coolingDown(symbol: symbol, until: until)
            statusText = "REST stabilizasyonu"
        } else {
            websocketCooldownUntil = nil
            liveState = .idle
            statusText = "Yedek akış"
        }

        sourceText = "Binance REST"
        lastError = normalizedDisconnectReason(reason)
        runtimeMetrics?.recordReconnect()

        scheduleReconnect(symbol: symbol, delay: reconnectDelay)
    }

    private func scheduleInitialFallbackProbe(symbol: String) {
        guard isSceneActive else { return }

        liveWarmupTask?.cancel()
        liveWarmupTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            guard let self else { return }

            let shouldProbe = await MainActor.run {
                guard self.started, !self.currentModeIsSim, self.currentSymbol == symbol, self.isSceneActive else { return false }
                return self.lastWebSocketTickAt == nil
            }

            guard shouldProbe else { return }
            await self.refreshFallbackTick(symbol: symbol, reason: "Websocket ilk tick gecikti, geçici REST verisi kullanılıyor.")
        }
    }

    private func startFallbackWatchdog(symbol: String) {
        guard isSceneActive else { return }
        liveFallbackTask?.cancel()
        liveFallbackTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { break }

                guard let self else { break }

                let shouldRefresh: Bool = await MainActor.run {
                    guard self.started, !self.currentModeIsSim, self.currentSymbol == symbol else { return false }
                    guard self.isSceneActive else { return false }

                    if let lastWebSocketTickAt = self.lastWebSocketTickAt {
                        return Date().timeIntervalSince(lastWebSocketTickAt) >= 8
                    } else {
                        return true
                    }
                }

                guard shouldRefresh else { continue }

                let reason: String = await MainActor.run {
                    if self.lastWebSocketTickAt == nil {
                        return "İlk websocket tick bekleniyor."
                    } else {
                        return "Websocket akışı gecikti, yedek veri kullanılıyor."
                    }
                }

                await self.refreshFallbackTick(symbol: symbol, reason: reason)
            }
        }
    }

    private func scheduleReconnect(symbol: String, delay: TimeInterval? = nil) {
        guard isSceneActive else { return }
        liveReconnectTask?.cancel()

        let reconnectDelay = max(delay ?? reconnectDelayForCurrentState(), 3)

        liveReconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(reconnectDelay))
            guard !Task.isCancelled else { return }
            guard let self else { return }

            await MainActor.run {
                guard self.started, !self.currentModeIsSim, self.currentSymbol == symbol else {
                    self.liveReconnectTask = nil
                    return
                }
                guard self.isSceneActive else {
                    self.liveReconnectTask = nil
                    return
                }

                self.binanceAdapter?.disconnect()
                self.binanceAdapter = nil
                self.liveReconnectTask = nil
                self.startLive(symbol: symbol)
            }
        }
    }

    private func refreshFallbackTick(symbol: String, reason: String) async {
        let shouldRun = await MainActor.run {
            started && !currentModeIsSim && currentSymbol == symbol && isSceneActive
        }
        guard shouldRun else { return }

        do {
            let tick = try await fetchRESTTick(symbol: symbol)

            await MainActor.run {
                guard self.started, !self.currentModeIsSim, self.currentSymbol == symbol else { return }

                if let lastWebSocketTickAt, Date().timeIntervalSince(lastWebSocketTickAt) < 3 {
                    return
                }

                self.last = tick
                self.metrics.recordTick()
                self.runtimeMetrics?.recordRestFallback()
                self.sourceText = "Binance REST"
                self.statusText = "Otomatik yedek"
                self.lastError = reason
            }
        } catch {
            await MainActor.run {
                guard self.started, !self.currentModeIsSim, self.currentSymbol == symbol else { return }
                self.statusText = "Veri bekleniyor"
                self.sourceText = "Canlı akış"
                self.lastError = "Canlı piyasa verisi alınamadı: \(error.localizedDescription)"
            }
        }
    }

    private func refreshFallbackIfNeeded(symbol: String, reason: String) {
        let hasFreshTick: Bool
        if let last {
            hasFreshTick = Date().timeIntervalSince(last.ts) < 10
        } else {
            hasFreshTick = false
        }

        guard !hasFreshTick else { return }

        Task { [weak self] in
            guard let self else { return }
            await self.refreshFallbackTick(symbol: symbol, reason: reason)
        }
    }

    private func reconnectDelayForCurrentState() -> TimeInterval {
        switch websocketFailureCount {
        case 0, 1:
            return 5
        case 2:
            return 15
        case 3:
            return 45
        default:
            return 90
        }
    }

    private func preferredEndpoint() -> BinanceAdapter.Endpoint {
        switch websocketFailureCount {
        case 0:
            return .marketDataVision
        case 1:
            return .stream443
        default:
            return .stream9443
        }
    }

    private func normalizedDisconnectReason(_ reason: String) -> String {
        let lowered = reason.lowercased()
        if lowered.contains("timed out") || lowered.contains("-1001") {
            return "Binance websocket zaman aşımına uğradı. REST yedek akışı aktif."
        }
        return reason
    }

    private func fetchRESTTick(symbol: String) async throws -> Tick {
        let escapedSymbol = symbol.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? symbol
        let url = URL(string: "https://api.binance.com/api/v3/ticker/24hr?symbol=\(escapedSymbol)")!
        let (data, response) = try await session.data(from: url)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let payload = try JSONDecoder().decode(BinanceRESTTickerPayload.self, from: data)

        guard
            let price = Double(payload.lastPrice),
            let volume = Double(payload.volume)
        else {
            throw URLError(.cannotParseResponse)
        }

        let timestamp = Date(timeIntervalSince1970: payload.closeTime / 1_000)
        return Tick(ts: timestamp, price: price, vol: volume)
    }

    private func publish(_ updates: @escaping (MarketDataService) -> Void) {
        updates(self)
    }
}

private struct BinanceRESTTickerPayload: Decodable {
    let lastPrice: String
    let volume: String
    let closeTime: TimeInterval
}
