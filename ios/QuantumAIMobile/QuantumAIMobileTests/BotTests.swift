import XCTest
@testable import QuantumAIMobile

@MainActor
final class BotTests: XCTestCase {
    func testGridLevelsNotEmpty() {
        let lower = 48_000.0
        let upper = 52_000.0
        let steps = 5
        let levels = Array(stride(from: lower, through: upper, by: (upper - lower) / Double(steps)))
        XCTAssertFalse(levels.isEmpty)
    }

    func testIdempotencyKeyStable() {
        let a = SecureRandom.idempotencyKey("abc", hourBucket: 1)
        let b = SecureRandom.idempotencyKey("abc", hourBucket: 1)
        XCTAssertEqual(a, b)
    }

    func testStorageDropsDuplicates() {
        let storage = StorageService(persistenceEnabled: false)
        let order = Order(
            id: "duplicate-order",
            symbol: "BTCUSDT",
            side: "BUY",
            price: 100,
            amount: 0.1,
            timestamp: .now
        )
        storage.append(order: order)
        storage.append(order: order)
        XCTAssertEqual(storage.orders.count, 1)
        XCTAssertEqual(storage.duplicateDrops, 1)
    }

    func testQueueForBroadcastDoesNotDuplicateOutboxEntries() {
        let storage = StorageService(persistenceEnabled: false)
        storage.clearOutbox()
        let order = Order(
            id: "duplicate-outbox",
            symbol: "BTCUSDT",
            side: "BUY",
            price: 100,
            amount: 0.1,
            timestamp: .now
        )

        storage.queueForBroadcast(order)
        storage.queueForBroadcast(order)

        XCTAssertEqual(storage.orders.count, 1)
        XCTAssertEqual(storage.outbox.count, 1)
        XCTAssertEqual(storage.duplicateDrops, 1)
    }

    func testStorageRetentionCapsLongRunningCollections() {
        let storage = StorageService(persistenceEnabled: false)
        storage.clearOutbox()

        for index in 0..<2_200 {
            storage.queueForBroadcast(
                Order(
                    id: "order-\(index)",
                    symbol: "BTCUSDT",
                    side: index.isMultiple(of: 2) ? "BUY" : "GRID",
                    price: 100 + Double(index),
                    amount: 0.1,
                    timestamp: .now
                )
            )
        }

        for index in 0..<4_300 {
            storage.appendAudit(
                AuditRecord(
                    id: UUID(),
                    ts: .now,
                    action: "audit-\(index)",
                    payloadHash: "\(index)",
                    actor: "test"
                )
            )
        }

        XCTAssertEqual(storage.orders.count, 2_048)
        XCTAssertEqual(storage.outbox.count, 512)
        XCTAssertEqual(storage.audits.count, 4_096)
    }

    func testBotActionsQueueOrdersAndPanicStopClearsState() {
        let metrics = MetricsCenter()
        let storage = StorageService(persistenceEnabled: false)
        storage.clearOutbox()
        let audit = AuditService(storage: storage)
        let market = MarketDataService(metrics: metrics)
        let bot = BotService(market: market, storage: storage, audit: audit, metrics: metrics)

        let initialOrders = storage.orders.count

        bot.startDCA(amount: 25, periodSec: 60)
        XCTAssertEqual(bot.activeOrders.count, 1)
        XCTAssertEqual(storage.outbox.count, 1)
        XCTAssertEqual(storage.orders.count, initialOrders + 1)

        bot.startGrid(lower: 48_000, upper: 52_000, steps: 5)
        XCTAssertEqual(bot.activeOrders.count, 2)
        XCTAssertEqual(storage.outbox.count, 2)
        XCTAssertEqual(storage.orders.count, initialOrders + 2)

        bot.stopAll()
        XCTAssertTrue(bot.activeOrders.isEmpty)
        XCTAssertTrue(storage.outbox.isEmpty)
    }

    func testRepeatedStrategyStartsAreIgnored() {
        let metrics = MetricsCenter()
        let storage = StorageService(persistenceEnabled: false)
        storage.clearOutbox()
        let audit = AuditService(storage: storage)
        let market = MarketDataService(metrics: metrics)
        let bot = BotService(market: market, storage: storage, audit: audit, metrics: metrics)

        bot.startDCA(amount: 25, periodSec: 60)
        bot.startDCA(amount: 25, periodSec: 60)
        XCTAssertEqual(bot.activeOrders.filter { $0.side == "BUY" }.count, 1)
        XCTAssertEqual(storage.outbox.filter { $0.side == "BUY" }.count, 1)

        bot.startGrid(lower: 48_000, upper: 52_000, steps: 5)
        bot.startGrid(lower: 48_000, upper: 52_000, steps: 5)
        XCTAssertEqual(bot.activeOrders.filter { $0.side == "GRID" }.count, 1)
        XCTAssertEqual(storage.outbox.filter { $0.side == "GRID" }.count, 1)
    }

    func testCopyTradeStartIsIdempotent() {
        let metrics = MetricsCenter()
        let storage = StorageService(persistenceEnabled: false)
        let audit = AuditService(storage: storage)
        let market = MarketDataService(metrics: metrics)
        let copyTrade = CopyTradeService(market: market, storage: storage, audit: audit, metrics: metrics)

        copyTrade.start(source: "LOCAL_FEED", ratio: 1.5)
        let initialAuditCount = storage.audits.count
        copyTrade.start(source: "LOCAL_FEED", ratio: 1.5)

        XCTAssertTrue(copyTrade.isActive)
        XCTAssertEqual(storage.audits.count, initialAuditCount)
    }
}
