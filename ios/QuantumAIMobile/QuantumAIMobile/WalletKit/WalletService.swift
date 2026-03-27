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
        let key = try loadOrCreatePrivateKey()
        return "qaidemo_" + Data(key.publicKey.rawRepresentation).base64EncodedString()
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
}
