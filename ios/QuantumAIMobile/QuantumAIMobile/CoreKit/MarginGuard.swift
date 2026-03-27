import Foundation

public final class MarginGuard {
    public static let shared = MarginGuard()

    public init() {}

    public func evaluateRisk(currentPrice: Double, liquidationPrice: Double, leverage: Int) {
        let safetyMargin = (currentPrice - liquidationPrice) / max(currentPrice, 1)

        if safetyMargin < 0.05 {
            GlobalSinirSistemi.paylasilan.veriPompala(
                kategori: .alarm,
                mesaj: "MARGIN GUARD: \(leverage)x pozisyon risk altinda.",
                veri: ["margin": safetyMargin]
            )
        }
    }
}
