import Combine
import Foundation

@MainActor
public final class WealthBridge: ObservableObject {
    public static let shared = WealthBridge()
    public let profitThreshold: Double = 5_000.0
    public let targetAccountLabel = "Bursa_Property_Acc"

    @Published public private(set) var statusText = "BEKLEMEDE"
    @Published public private(set) var lastTransferredAmount: Double?
    @Published public private(set) var lastTransferredAt: Date?

    private let bursaPropertyIBAN = "TR7600012009443..."
    private let minimumTransferCooldown: TimeInterval = 60

    public init() {}

    public func checkAndWithdraw(currentProfit: Double) {
        evaluateWithdrawal(currentProfit: currentProfit)
    }

    public func evaluateWithdrawal(currentProfit: Double) {
        guard currentProfit >= profitThreshold else {
            statusText = "BEKLEMEDE"
            return
        }

        if let lastTransferredAt, Date().timeIntervalSince(lastTransferredAt) < minimumTransferCooldown {
            statusText = "ESIK ASILDI"
            return
        }

        executeTransfer(amount: currentProfit)
    }

    private func executeTransfer(amount: Double) {
        statusText = "TETIKLENDI"
        lastTransferredAmount = amount
        lastTransferredAt = .now

        GlobalSinirSistemi.paylasilan.veriPompala(
            kategori: .kar,
            mesaj: "WEALTH BRIDGE: $\(amount.formatted(.number.precision(.fractionLength(2)))) USDT kar fiziksel hesap akisina kaydedildi.",
            veri: ["target": targetAccountLabel, "iban": bursaPropertyIBAN, "amount": amount]
        )
    }
}
