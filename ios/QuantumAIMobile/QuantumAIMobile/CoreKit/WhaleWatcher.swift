import Foundation

/// Tracks oversized market moves and forwards alerts into the shared sync bus.
public final class WhaleWatcher: ObservableObject {
    public static let shared = WhaleWatcher()

    public init() {}

    public func startSniffing() {
        print("WHALE WATCHER: Mempool izleme baslatildi.")
    }

    public func processLargeTransaction(amount: Double, asset: String) {
        guard amount > 1_000_000 else { return }
        GlobalSinirSistemi.paylasilan.veriPompala(
            kategori: .pazarlama,
            mesaj: "WHALE ALERT: \(amount.formatted(.number.precision(.fractionLength(0)))) \(asset) hareketi saptandi.",
            veri: ["impact": "HIGH", "asset": asset, "amount": amount]
        )
    }
}
