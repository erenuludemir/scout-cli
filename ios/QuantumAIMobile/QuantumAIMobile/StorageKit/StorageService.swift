import Foundation
import Combine

public final class StorageService: ObservableObject {
    private enum Retention {
        static let maxOrders = 2_048
        static let maxOutbox = 512
        static let maxAudits = 4_096
    }

    @Published public private(set) var orders: [Order] = []
    @Published public private(set) var outbox: [Order] = []
    @Published public private(set) var audits: [AuditRecord] = []
    @Published public private(set) var duplicateDrops: Int = 0
    private let persistenceEnabled: Bool
    private var idempotencySet = Set<String>()

    public init(persistenceEnabled: Bool = true) {
        self.persistenceEnabled = persistenceEnabled
        bootstrap()
    }

    @discardableResult
    public func append(order: Order) -> Bool {
        // Use the order's id as an idempotency key
        guard !idempotencySet.contains(order.id) else {
            duplicateDrops += 1
            persistMetrics()
            return false
        }
        idempotencySet.insert(order.id)
        orders.append(order)
        trimOrdersIfNeeded()
        persistOrders()
        persistMetrics()
        return true
    }

    public func queueForBroadcast(_ order: Order) {
        guard append(order: order) else { return }
        outbox.append(order)
        trimOutboxIfNeeded()
        persistOutbox()
    }

    public func removeFromOutbox(_ id: String) {
        outbox.removeAll { $0.id == id }
        rebuildIdempotencySet()
        persistOutbox()
    }

    public func clearOutbox() {
        outbox.removeAll()
        rebuildIdempotencySet()
        persistOutbox()
    }

    public func appendAudit(_ record: AuditRecord) {
        audits.append(record)
        trimAuditsIfNeeded()
        persistAudits()
    }

    public func exportOrdersCSV() -> URL? {
        let url = documentsURL().appendingPathComponent("orders.csv")
        let lines = orders.map { order in
            let usd = order.price * order.amount
            let desc = "\(order.side) \(order.amount) \(order.symbol)"
            let status = "queued"
            return "\(order.timestamp),\(order.symbol),\(order.side),\(order.price),\(order.amount),\(order.id),\(usd),\(desc),\(status)"
        }
        do {
            try lines.joined(separator: "\n").data(using: .utf8)?.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    public func queueDepth() -> Int {
        outbox.count
    }

    private func bootstrap() {
        guard persistenceEnabled else { return }
        loadOutbox()
        rebuildIdempotencySet()
        _ = exportOrdersCSV()
    }

    private func loadOutbox() {
        let url = documentsURL().appendingPathComponent("outbox.json")
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Order].self, from: data) else { return }
        outbox = decoded
        trimOutboxIfNeeded()
    }

    private func persistOrders() {
        guard persistenceEnabled else { return }
        let url = documentsURL().appendingPathComponent("orders.json")
        do {
            let data = try JSONEncoder().encode(orders)
            try data.write(to: url, options: .atomic)
        } catch {}
    }

    private func persistOutbox() {
        guard persistenceEnabled else { return }
        let url = documentsURL().appendingPathComponent("outbox.json")
        do {
            let data = try JSONEncoder().encode(outbox)
            try data.write(to: url, options: .atomic)
        } catch {}
    }

    private func persistAudits() {
        guard persistenceEnabled else { return }
        let url = documentsURL().appendingPathComponent("audit.json")
        do {
            let data = try JSONEncoder().encode(audits)
            try data.write(to: url, options: .atomic)
        } catch {}
    }

    private func persistMetrics() {
        guard persistenceEnabled else { return }
        let url = documentsURL().appendingPathComponent("metrics.json")
        let payload = ["duplicateDrops": duplicateDrops]
        do {
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
            try data.write(to: url, options: .atomic)
        } catch {}
    }

    private func documentsURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func trimOrdersIfNeeded() {
        trim(&orders, limit: Retention.maxOrders)
        rebuildIdempotencySet()
    }

    private func trimOutboxIfNeeded() {
        trim(&outbox, limit: Retention.maxOutbox)
        rebuildIdempotencySet()
    }

    private func trimAuditsIfNeeded() {
        trim(&audits, limit: Retention.maxAudits)
    }

    private func rebuildIdempotencySet() {
        idempotencySet = Set(orders.lazy.map(\.id))
        idempotencySet.formUnion(outbox.lazy.map(\.id))
    }

    private func trim<T>(_ items: inout [T], limit: Int) {
        guard items.count > limit else { return }
        items.removeFirst(items.count - limit)
    }
}
