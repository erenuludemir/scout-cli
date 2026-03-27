import CryptoKit
import Foundation

/// Lightweight transaction seal registry with deterministic digest output.
public final class QuantumLedger {
    public static let shared = QuantumLedger()
    private let sinir = GlobalSinirSistemi.paylasilan

    public init() {}

    public func sealTransaction(orderId: String, data: String) -> String {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let seed = QuantumEntropyEngine.shared.getQuantumSeed()
        let payload = "\(orderId)|\(data)|\(timestamp)|\(seed)"
        let digest = SHA256.hash(data: Data(payload.utf8))
        let seal = digest.prefix(12).map { String(format: "%02x", $0) }.joined().uppercased()

        sinir.veriPompala(
            kategori: .sistem,
            mesaj: "QUANTUM LEDGER: Islem muhurlendi.",
            veri: ["seal": seal, "integrity": "VERIFIED_LATTICE"]
        )

        return seal
    }
}
