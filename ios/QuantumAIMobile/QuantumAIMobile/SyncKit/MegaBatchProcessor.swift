import Foundation

public final class MegaBatchProcessor: ObservableObject {
    public static let shared = MegaBatchProcessor()
    private var orderQueue: [Order] = []
    private let batchLimit = 100

    public init() {}

    public func queueOrder(_ order: Order) {
        orderQueue.append(order)
        if orderQueue.count >= batchLimit {
            flushBatch()
        }
    }

    private func flushBatch() {
        let totalAmount = orderQueue.reduce(0) { $0 + $1.amount }
        GlobalSinirSistemi.paylasilan.veriPompala(
            kategori: .emir,
            mesaj: "BATCH EXECUTION: \(batchLimit) TX aggregated.",
            veri: ["total": totalAmount]
        )
        orderQueue.removeAll()
    }
}
