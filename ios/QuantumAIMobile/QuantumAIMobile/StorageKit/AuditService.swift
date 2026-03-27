import Foundation
import CryptoKit

public final class AuditService {
    private let storage: StorageService
    private var lastHash = ""

    public init(storage: StorageService) {
        self.storage = storage
    }

    public func append(action: String, payload: [String: Any]) {
        let normalized = payload.keys.sorted().map { "\($0)=\(payload[$0] ?? "")" }.joined(separator: "&")
        let chainInput = "\(action)|\(normalized)|\(lastHash)"
        let digest = SHA256.hash(data: Data(chainInput.utf8))
        let hash = Data(digest).base64EncodedString()
        lastHash = hash
        storage.appendAudit(
            AuditRecord(
                id: UUID(),
                ts: .now,
                action: action,
                payloadHash: hash,
                actor: "device"
            )
        )
    }
}
