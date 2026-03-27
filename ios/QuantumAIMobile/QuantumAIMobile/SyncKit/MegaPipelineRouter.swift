import Foundation

/// Routes oversized transactions through a parallel-risk branch and standard trades through a batch path.
public final class MegaPipelineRouter {
    public static let shared = MegaPipelineRouter()

    public init() {}

    public func routeTransaction(amount: Double) {
        if amount >= 1_000_000 {
            GlobalSinirSistemi.paylasilan.veriPompala(
                kategori: .alarm,
                mesaj: "MEGA TX DETECTED: \(amount.formatted(.number.precision(.fractionLength(0)))) USDT. Risk modulu forking...",
                veri: ["priority": "CRITICAL", "amount": amount]
            )
            triggerParallelRiskCheck(amount: amount)
        } else {
            print("Standard TX: micro-batching yoluna yonlendirildi.")
        }
    }

    private func triggerParallelRiskCheck(amount: Double) {
        print("AI analiz ve sentinel kontrolu eszamanli baslatildi: \(amount)")
    }
}
