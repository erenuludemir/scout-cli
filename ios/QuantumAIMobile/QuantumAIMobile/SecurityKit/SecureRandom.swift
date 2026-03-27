import Foundation
import Security
import CryptoKit

public enum SecureRandom {
    public static func bytes(_ count: Int) throws -> Data {
        var buffer = [UInt8](repeating: 0, count: count)
        let rc = SecRandomCopyBytes(kSecRandomDefault, count, &buffer)
        guard rc == errSecSuccess else {
            throw NSError(domain: "SecureRandom", code: Int(rc))
        }
        return Data(buffer)
    }

    public static func idempotencyKey(_ input: String, hourBucket: Int) -> String {
        let payload = Data("\(input)|\(hourBucket)".utf8)
        let digest = SHA256.hash(data: payload)
        return Data(digest).base64EncodedString()
    }
}
