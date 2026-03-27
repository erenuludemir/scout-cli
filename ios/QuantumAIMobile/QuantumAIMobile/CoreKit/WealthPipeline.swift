import Foundation

public final class WealthPipeline {
    public static let shared = WealthPipeline()

    public init() {}

    public func simulateWealthPath(startBalance: Double = 10.0, target: Double = 1_000_000.0) {
        let successProbability = 0.024
        let estimatedDays = 180

        GlobalSinirSistemi.paylasilan.veriPompala(
            kategori: .kar,
            mesaj: "WEALTH PATH: %\(successProbability * 100) ihtimalle \(estimatedDays) gunde hedefe ulasilabilir.",
            veri: ["start": startBalance, "target": target]
        )
    }
}
