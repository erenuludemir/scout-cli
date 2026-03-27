import CryptoKit
import Foundation
import Security

/// High-entropy seed and key generation wrapper.
public final class QuantumEntropyEngine {
    public static let shared = QuantumEntropyEngine()

    public init() {}

    public func generateHighEntropyKey() -> SymmetricKey {
        SymmetricKey(size: .bits256)
    }

    public func getQuantumSeed() -> UInt64 {
        var random: UInt64 = 0
        let status = withUnsafeMutableBytes(of: &random) { bytes in
            SecRandomCopyBytes(kSecRandomDefault, bytes.count, bytes.baseAddress!)
        }
        if status != errSecSuccess {
            random = UInt64.random(in: .min ... .max)
        }
        return random
    }
}
