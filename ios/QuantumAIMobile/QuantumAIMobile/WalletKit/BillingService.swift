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

    public init(amount: Double, currency: String = "Free Access", address: String = "No payment required", status: Status = .confirmed) {
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
        self.currentInvoice = Invoice(amount: 0.0)
        audit.append(action: "billing.invoice.created", payload: ["amount": 0.0, "mode": "free"])
    }

    public func checkPaymentStatus() async -> Bool {
        audit.append(action: "billing.invoice.checked", payload: ["status": "confirmed", "mode": "free"])
        return true
    }
}
