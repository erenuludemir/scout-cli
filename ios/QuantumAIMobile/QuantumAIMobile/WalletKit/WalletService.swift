import Foundation
import CryptoKit

public struct RawTransaction {
    public let chainId: Int
    public let nonce: UInt64
    public let to: String
    public let value: Decimal
    public let data: Data

    public init(chainId: Int, nonce: UInt64, to: String, value: Decimal, data: Data) {
        self.chainId = chainId
        self.nonce = nonce
        self.to = to
        self.value = value
        self.data = data
    }
}

public final class WalletService {
    private let storage: StorageService
    private let auditService: AuditService
    private let keyTag = "com.quantumai.mobile.ed25519"

    public init(storage: StorageService, audit: AuditService) {
        self.storage = storage
        self.auditService = audit
    }

    public func ensureKeypair() throws {
        if try loadPrivateKey() == nil {
            let key = Curve25519.Signing.PrivateKey()
            try KeychainStore.save(tag: keyTag, data: key.rawRepresentation)
            auditService.append(action: "wallet.created", payload: ["tag": keyTag])
        }
    }

    public func address() throws -> String {
        try address(for: WalletChainRegistry.defaultNetwork)
    }

    public func address(for network: WalletNetwork, configuredAddresses: [String: String] = [:]) throws -> String {
        let normalizedAddresses = configuredAddresses.reduce(into: [String: String]()) { partialResult, entry in
            partialResult[entry.key.lowercased()] = entry.value
        }
        let candidates = [
            normalizedAddresses[network.id],
            normalizedAddresses[network.family.rawValue],
            network.family == .evm ? normalizedAddresses["ethereum"] : nil,
            normalizedAddresses["default"],
        ]
        if let configuredAddress = candidates
            .compactMap({ $0?.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { !$0.isEmpty })
        {
            return configuredAddress
        }

        let key = try loadOrCreatePrivateKey()
        let publicKey = Data(key.publicKey.rawRepresentation)

        switch network.family {
        case .evm:
            let hash = Data(SHA256.hash(data: publicKey))
            return "0x" + Self.hexString(hash.suffix(20))
        case .tron:
            let hash = Data(SHA256.hash(data: publicKey))
            var payload = Data([0x41])
            payload.append(hash.suffix(20))
            return Self.base58CheckEncode(payload)
        case .solana:
            return Self.base58Encode(publicKey)
        case .bitcoin:
            let hash = Data(SHA256.hash(data: publicKey))
            var payload = Data([0x00])
            payload.append(hash.prefix(20))
            return Self.base58CheckEncode(payload)
        }
    }

    public func sign(_ message: Data) throws -> Data {
        let key = try loadOrCreatePrivateKey()
        auditService.append(action: "wallet.sign", payload: ["bytes": message.count])
        return try key.signature(for: message)
    }

    public func signEVM(tx: RawTransaction) throws -> Data {
        let txSummary = "eip155:\(tx.chainId):\(tx.nonce):\(tx.to):\(tx.value)"
        let txData = Data(txSummary.utf8)
        let hashed = SHA256.hash(data: txData)
        auditService.append(action: "wallet.evm_sign", payload: ["to": tx.to, "value": "\(tx.value)"])
        return try sign(Data(hashed))
    }

    public func signTRON(txHash: Data) throws -> Data {
        auditService.append(action: "wallet.tron_sign", payload: ["hash": txHash.base64EncodedString()])
        return try sign(txHash)
    }

    public func signSolana(message: Data) throws -> Data {
        auditService.append(action: "wallet.solana_sign", payload: ["bytes": message.count])
        return try sign(message)
    }

    public func signBitcoin(transaction: Data) throws -> Data {
        auditService.append(action: "wallet.bitcoin_sign", payload: ["bytes": transaction.count])
        return try sign(transaction)
    }

    public func supportedNetworks(family: WalletNetworkFamily? = nil) -> [WalletNetwork] {
        WalletChainRegistry.supportedNetworks(family: family)
    }

    private func loadPrivateKey() throws -> Curve25519.Signing.PrivateKey? {
        guard let data = try KeychainStore.load(tag: keyTag) else {
            return nil
        }
        return try? Curve25519.Signing.PrivateKey(rawRepresentation: data)
    }

    private func loadOrCreatePrivateKey() throws -> Curve25519.Signing.PrivateKey {
        if let key = try loadPrivateKey() {
            return key
        }

        try ensureKeypair()

        if let key = try loadPrivateKey() {
            return key
        }

        throw NSError(domain: "WalletService", code: -1)
    }

    private static func hexString<T: DataProtocol>(_ data: T) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    private static func base58CheckEncode(_ payload: Data) -> String {
        var checksumInput = payload
        let firstHash = Data(SHA256.hash(data: checksumInput))
        checksumInput = Data(SHA256.hash(data: firstHash).prefix(4))
        return base58Encode(payload + checksumInput)
    }

    private static func base58Encode(_ data: Data) -> String {
        guard !data.isEmpty else { return "" }

        let alphabet = Array("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")
        var bytes = [UInt8](data)
        var zeros = 0
        while zeros < bytes.count, bytes[zeros] == 0 {
            zeros += 1
        }

        var encoded: [Character] = []
        var startIndex = zeros
        while startIndex < bytes.count {
            var remainder = 0
            for index in startIndex..<bytes.count {
                let value = Int(bytes[index]) + remainder * 256
                bytes[index] = UInt8(value / 58)
                remainder = value % 58
            }
            encoded.append(alphabet[remainder])
            while startIndex < bytes.count, bytes[startIndex] == 0 {
                startIndex += 1
            }
        }

        if zeros > 0 {
            encoded.append(contentsOf: Array(repeating: alphabet[0], count: zeros))
        }

        return String(encoded.reversed())
    }
}
