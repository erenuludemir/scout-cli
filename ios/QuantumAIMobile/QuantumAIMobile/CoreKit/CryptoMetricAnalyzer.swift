import Foundation

public final class CryptoMetricAnalyzer {
    public static let shared = CryptoMetricAnalyzer()

    public enum ThreatLevel {
        case none
        case low
        case critical
    }

    public init() {}

    public func evaluateThreat(algorithm: String, keySize: Int) -> ThreatLevel {
        switch algorithm.uppercased() {
        case "RSA", "ECC":
            return .critical
        case "AES":
            return keySize < 256 ? .low : .none
        default:
            return .none
        }
    }
}
