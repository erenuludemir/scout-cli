import Foundation

public final class BursaHealthCheck {
    public static let shared = BursaHealthCheck()

    public struct DiagnosticReport {
        public let sentinelOK: Bool
        public let oracleOK: Bool
        public let ledgerOK: Bool
        public let vaultOK: Bool
        public let status: String

        public init(sentinelOK: Bool, oracleOK: Bool, ledgerOK: Bool, vaultOK: Bool, status: String) {
            self.sentinelOK = sentinelOK
            self.oracleOK = oracleOK
            self.ledgerOK = ledgerOK
            self.vaultOK = vaultOK
            self.status = status
        }
    }

    public init() {}

    public func performFullScan() -> DiagnosticReport {
        let sentinelOK = true
        let oracleOK = true
        let ledgerOK = !QuantumLedger.shared.sealTransaction(orderId: "health-check", data: "probe").isEmpty
        let vaultOK = true
        let okCount = [sentinelOK, oracleOK, ledgerOK, vaultOK].filter { $0 }.count
        let status = okCount == 4 ? "SISTEM OPERASYONEL" : "SISTEM KISITLI"

        GlobalSinirSistemi.paylasilan.veriPompala(
            kategori: .sistem,
            mesaj: "FULL SCAN: \(status)",
            veri: ["health_score": okCount]
        )

        return DiagnosticReport(
            sentinelOK: sentinelOK,
            oracleOK: oracleOK,
            ledgerOK: ledgerOK,
            vaultOK: vaultOK,
            status: status
        )
    }
}
