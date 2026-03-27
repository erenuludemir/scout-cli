import Foundation
import SwiftUI

@MainActor
public final class TokenFactory: ObservableObject {
    public static let shared = TokenFactory()

    public enum NetworkStandard: String, CaseIterable {
        case erc20 = "Ethereum"
        case trc20 = "Tron"
    }

    @Published public private(set) var deployedTokens: [String] = [
        "QAI",
        "BURSA",
        "OPS"
    ]

    private init() {}

    public func deployToken(name: String, symbol: String, supply: Double, network: NetworkStandard) {
        let tokenKey = "\(symbol.uppercased())-\(network.rawValue)"
        if !deployedTokens.contains(tokenKey) {
            deployedTokens.insert(tokenKey, at: 0)
        }

        GlobalSinirSistemi.paylasilan.veriPompala(
            kategori: .sistem,
            mesaj: "TOKEN DEPLOYED (SIMULATED): \(symbol.uppercased()) on \(network.rawValue)",
            veri: [
                "supply": supply,
                "network": network.rawValue,
                "mode": "dry_run"
            ]
        )
    }
}
