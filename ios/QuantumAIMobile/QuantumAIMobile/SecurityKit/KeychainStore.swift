import Foundation
import Security

public enum KeychainStore {
    public static func save(tag: String, data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        let rc = SecItemAdd(query as CFDictionary, nil)
        guard rc == errSecSuccess else {
            throw NSError(domain: "KeychainStore", code: Int(rc))
        }
    }

    public static func load(tag: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecReturnData as String: true
        ]
        var output: CFTypeRef?
        let rc = SecItemCopyMatching(query as CFDictionary, &output)
        if rc == errSecItemNotFound {
            return nil
        }
        guard rc == errSecSuccess else {
            throw NSError(domain: "KeychainStore", code: Int(rc))
        }
        return output as? Data
    }
}
