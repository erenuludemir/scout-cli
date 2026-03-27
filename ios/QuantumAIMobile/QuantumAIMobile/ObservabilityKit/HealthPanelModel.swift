import Foundation
import Combine

@MainActor
public final class HealthPanelModel: ObservableObject {
    @Published public var queueDepth: Int = 0
    @Published public var retryRate: Double = 0
    @Published public var duplicateDrops: Int = 0
    @Published public var p95LatencyMs: Double = 0

    private let storage: StorageService
    private let metrics: MetricsCenter
    private let sync: SyncClient
    private let market: MarketDataService
    private var cancellables = Set<AnyCancellable>()
    private var isBound = false

    public init(storage: StorageService, metrics: MetricsCenter, sync: SyncClient, market: MarketDataService) {
        self.storage = storage
        self.metrics = metrics
        self.sync = sync
        self.market = market
    }

    public func bind() {
        guard !isBound else { return }
        isBound = true

        storage.$orders
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        storage.$outbox
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        storage.$duplicateDrops
            .sink { [weak self] value in self?.duplicateDrops = value }
            .store(in: &cancellables)

        refresh()
    }

    public func unbind() {
        cancellables.removeAll()
        isBound = false
    }

    private func refresh() {
        queueDepth = storage.queueDepth()
        duplicateDrops = storage.duplicateDrops
        p95LatencyMs = metrics.p95()
        retryRate = sync.retryRate()
    }

    deinit {
        cancellables.removeAll()
    }
}
