import Foundation
import Combine

@MainActor
public final class BotService: ObservableObject {
    @Published public private(set) var activeOrders: [Order] = []
    private var cancellables = Set<AnyCancellable>()
    private let market: MarketDataService
    private let storage: StorageService
    private let audit: AuditService
    private let metrics: MetricsCenter

    public var isDCAActive: Bool {
        activeOrders.contains { $0.side == "BUY" }
    }

    public var isGridActive: Bool {
        activeOrders.contains { $0.side == "GRID" }
    }

    public var activeStrategyCount: Int {
        var count = 0
        if isDCAActive { count += 1 }
        if isGridActive { count += 1 }
        return count
    }

    public init(market: MarketDataService, storage: StorageService, audit: AuditService, metrics: MetricsCenter) {
        self.market = market
        self.storage = storage
        self.audit = audit
        self.metrics = metrics
    }

    public func startDCA(amount: Double, periodSec: Int) {
        guard !isDCAActive else { return }
        let price = currentMarketPrice()
        let quantity = max(amount / max(price, 1), 0.0001)
        let order = generateMockOrder(side: "BUY", price: price, amount: quantity)
        activeOrders.insert(order, at: 0)
        storage.queueForBroadcast(order)
        audit.append(action: "bot.dca_start", payload: ["amount": amount, "periodSec": periodSec])
        metrics.recordOrderLatency(Double.random(in: 80...140))
        
        GlobalSinirSistemi.paylasilan.veriPompala(
            kategori: .emir, 
            mesaj: "DCA Başlatıldı: $\(amount)", 
            veri: ["bot": "DCA"]
        )
    }

    public func stopDCA() {
        removeActiveOrders { $0.side == "BUY" }
        audit.append(action: "bot.dca_stop", payload: [:])
    }

    public func startGrid(lower: Double, upper: Double, steps: Int) {
        guard !isGridActive else { return }
        let midpoint = (lower + upper) / 2
        let order = generateMockOrder(side: "GRID", price: midpoint, amount: max(Double(steps) * 0.001, 0.001))
        activeOrders.insert(order, at: 0)
        storage.queueForBroadcast(order)
        audit.append(action: "bot.grid_start", payload: ["range": "\(lower)-\(upper)"])
        metrics.recordOrderLatency(Double.random(in: 120...220))
        GlobalSinirSistemi.paylasilan.veriPompala(
            kategori: .emir, 
            mesaj: "Grid Kuruldu: \(steps) kademe", 
            veri: ["bot": "GRID"]
        )
    }

    public func stopGrid() {
        removeActiveOrders { $0.side == "GRID" }
        audit.append(action: "bot.grid_stop", payload: [:])
    }

    public func stopAll() {
        removeActiveOrders { _ in true }
        storage.clearOutbox()
        activeOrders.removeAll()
        audit.append(action: "bot.panic_stop", payload: [:])
    }

    public func exposureUSD() -> Double {
        activeOrders.reduce(0) { $0 + ($1.price * $1.amount) }
    }

    public func estimatedPnL(currentPrice: Double?) -> Double {
        guard let currentPrice else { return 0 }
        return activeOrders.reduce(0) { partial, order in
            partial + ((currentPrice - order.price) * order.amount)
        }
    }

    private func generateMockOrder(side: String, price: Double, amount: Double = 0.01) -> Order {
        return Order(
            id: UUID().uuidString.prefix(8).lowercased(),
            symbol: "BTCUSDT",
            side: side,
            price: price,
            amount: amount,
            timestamp: .now
        )
    }

    private func currentMarketPrice() -> Double {
        market.last?.price ?? 50_000
    }

    private func removeActiveOrders(where predicate: (Order) -> Bool) {
        let removed = activeOrders.filter(predicate)
        activeOrders.removeAll(where: predicate)
        removed.forEach { storage.removeFromOutbox($0.id) }
    }
}
