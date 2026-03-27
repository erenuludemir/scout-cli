import Foundation

public final class OnChainRadar {
    public static let shared = OnChainRadar()
    private let sinir = GlobalSinirSistemi.paylasilan

    public init() {}

    public func fetchWhaleActivity() -> [String] {
        let activities = [
            "2,500 BTC -> BINANCE (DUMP RISK)",
            "Smart Money Accm: +150 ETH",
            "XRP Large Movement: Unknown to Unknown"
        ]

        for activity in activities {
            sinir.veriPompala(
                kategori: .pazarlama,
                mesaj: "WHALE SIGNAL: \(activity)",
                veri: ["impact": activity.contains("DUMP") ? "HIGH" : "MEDIUM"]
            )
        }

        return activities
    }
}
