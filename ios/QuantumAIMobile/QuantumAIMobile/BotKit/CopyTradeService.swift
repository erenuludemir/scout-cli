import Foundation
import Combine

@MainActor
public final class CopyTradeService: ObservableObject {
    private let market: MarketDataService
    private let storage: StorageService
    private let audit: AuditService
    private let metrics: MetricsCenter
    private var cancellables = Set<AnyCancellable>()

    @Published public private(set) var isActive: Bool = false
    @Published public var followList: [String] = ["Whale-Master-01", "AI-Elite-Trader"]
    @Published public var copyRatio: Double = 0.10
    private var currentSource: String?
    private var currentRatio: Double = 0.10

    public init(market: MarketDataService, storage: StorageService, audit: AuditService, metrics: MetricsCenter) {
        self.market = market
        self.storage = storage
        self.audit = audit
        self.metrics = metrics
    }

    /// Starts the copy trade service with a given source and ratio.
    /// This sets the service to active and records an audit event.
    public func start(source: String, ratio: Double) {
        guard !isActive || currentSource != source || currentRatio != ratio else { return }
        currentSource = source
        currentRatio = ratio
        copyRatio = ratio
        isActive = true
        audit.append(action: "copytrade.start", payload: [
            "source": source,
            "ratio": ratio
        ])
        GlobalSinirSistemi.paylasilan.veriPompala(kategori: .emir, mesaj: "CopyTrade Başlatıldı", veri: [
            "source": source,
            "ratio": ratio
        ])
    }

    /// Stops the copy trade service, clearing any subscriptions and marking it inactive.
    public func stop() {
        guard isActive else { return }
        isActive = false
        currentSource = nil
        cancellables.removeAll()
        audit.append(action: "copytrade.stop", payload: [:])
        GlobalSinirSistemi.paylasilan.veriPompala(kategori: .emir, mesaj: "CopyTrade Durduruldu", veri: [:])
    }

    public func syncWithMarket(original: Order) {
        if let currentPrice = market.last?.price {
            let copiedOrder = executeMirroredOrder(originalOrder: original, marketPrice: currentPrice)
            audit.append(action: "copytrade.sync", payload: ["id": copiedOrder.id])
            GlobalSinirSistemi.paylasilan.veriPompala(kategori: .emir, mesaj: "CopyTrade Senkronize", veri: ["price": currentPrice])
        }
    }

    @discardableResult
    public func executeMirroredOrder(originalOrder: Order, marketPrice: Double? = nil) -> Order {
        let copiedPrice = marketPrice ?? market.last?.price ?? originalOrder.price
        let mirroredAmount = max(originalOrder.amount * copyRatio, 0.0001)
        let mirroredOrder = Order(
            id: UUID().uuidString.prefix(8).lowercased(),
            symbol: originalOrder.symbol,
            side: originalOrder.side,
            price: copiedPrice,
            amount: mirroredAmount,
            timestamp: .now
        )
        storage.queueForBroadcast(mirroredOrder)
        GlobalSinirSistemi.paylasilan.veriPompala(
            kategori: .emir,
            mesaj: "COPY-TRADE: \(originalOrder.side) emri kopyalandi.",
            veri: ["target": originalOrder.symbol, "amount": mirroredAmount]
        )
        return mirroredOrder
    }

    deinit {
        cancellables.removeAll()
    }
}
