import Foundation

public struct AuditRecord: Identifiable, Codable, Equatable {
    public let id: UUID
    public let ts: Date
    public let action: String
    public let payloadHash: String
    public let actor: String

    public init(id: UUID, ts: Date, action: String, payloadHash: String, actor: String) {
        self.id = id
        self.ts = ts
        self.action = action
        self.payloadHash = payloadHash
        self.actor = actor
    }
}
