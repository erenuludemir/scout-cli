import Foundation

public enum IntegrityStatus {
    case valid
    case compromised(atIndex: Int)
}

public final class IntegrityChecker {
    public static func validate(records: [AuditRecord]) -> IntegrityStatus {
        for (index, record) in records.enumerated() {
            if record.payloadHash.isEmpty {
                return .compromised(atIndex: index)
            }
        }
        return .valid
    }
}
