import Foundation

/// Minimal post-quantum readiness checks for symmetric key sizing.
public final class PQCGuard {
    public static func validateKeyLength(algorithm: String, length: Int) -> Bool {
        if algorithm.uppercased() == "AES" && length < 256 {
            print("KRITIK: Grover tehdidine karsi AES-256 zorunlulugu.")
            return false
        }
        return true
    }
}
