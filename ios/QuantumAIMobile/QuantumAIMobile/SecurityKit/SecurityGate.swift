import Foundation

public enum SecurityGateError: Error {
    case authFailed
}

public final class SecurityGate {
    public static func verifyAction(reason: String) async throws {
        let success = await BiometricGate.evaluate(reason: reason)
        if !success {
            throw SecurityGateError.authFailed
        }
    }
}
