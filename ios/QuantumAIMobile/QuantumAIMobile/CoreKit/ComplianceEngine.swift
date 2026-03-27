import Foundation

/// Compliance and invoicing helper for profitable order flows.
public final class ComplianceEngine {
    public static let shared = ComplianceEngine()
    private let sinir = GlobalSinirSistemi.paylasilan

    public init() {}

    public func sealAndInvoice(orderId: String, profit: Double, partnerId: String) {
        let taxRate = 0.20
        let taxAmount = profit * taxRate
        let invoiceID = "INV-\(UUID().uuidString.prefix(8).uppercased())"

        sinir.veriPompala(
            kategori: .sistem,
            mesaj: "LEGAL SEAL: \(invoiceID) olusturuldu. Vergi: $\(taxAmount.formatted(.number.precision(.fractionLength(2))))",
            veri: ["invoice_id": invoiceID, "tax": taxAmount, "partner": partnerId]
        )

        _ = QuantumLedger.shared.sealTransaction(orderId: orderId, data: "TAX_PAID_\(invoiceID)")
    }
}
