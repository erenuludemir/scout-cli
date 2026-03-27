import Foundation
import Combine

public struct Invoice: Identifiable, Equatable {
    public enum Status: String, Codable {
        case pending
        case confirmed
        case expired
    }

    public let id = UUID()
    public let amount: Double
    public let currency: String
    public let address: String
    public var status: Status

    public init(amount: Double, currency: String = "USDT (TRC20)", address: String = "TQaiSaaSServiceAddress", status: Status = .pending) {
        self.amount = amount
        self.currency = currency
        self.address = address
        self.status = status
    }
}

public final class BillingService: ObservableObject {
    @Published public var currentInvoice: Invoice?
    private let audit: AuditService

    public init(audit: AuditService) {
        self.audit = audit
    }

    public func createSubscriptionInvoice() {
        self.currentInvoice = Invoice(amount: 99.0)
        audit.append(action: "billing.invoice.created", payload: ["amount": 99.0])
    }

    public func checkPaymentStatus() async -> Bool {
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        audit.append(action: "billing.invoice.checked", payload: ["status": "confirmed"])
        return true
    }
}
