import Foundation
import LocalAuthentication

public enum BiometricGate {
    public static func evaluate(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        let canUse = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
        guard canUse else { return false }
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }
}
