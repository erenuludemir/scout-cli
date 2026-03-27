import Foundation

public final class ShannonSentinel {
    public static let shared = ShannonSentinel()

    public init() {}

    public func measureLeakage(packetEntropy: Double) -> Bool {
        if packetEntropy < 0.85 {
            GlobalSinirSistemi.paylasilan.veriPompala(
                kategori: .alarm,
                mesaj: "SHANNON PROTECT: Veri entropisi dustu, sizinti engellendi.",
                veri: ["entropy": packetEntropy]
            )
            return true
        }
        return false
    }
}
