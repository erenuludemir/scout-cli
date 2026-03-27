import Foundation

public final class SolanaProvider {
    private let rpcURL: URL
    private let sync: SyncClient

    public init(rpcURL: URL = URL(string: "https://api.mainnet-beta.solana.com")!, sync: SyncClient) {
        self.rpcURL = rpcURL
        self.sync = sync
    }

    public func broadcast(encodedTransaction: String, encoding: String = "base64") async -> Bool {
        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "method": "sendTransaction",
            "params": [encodedTransaction, ["encoding": encoding]]
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return false }
        return await sync.post(rpcURL, body: body, key: "SOLANA_TX_" + UUID().uuidString)
    }
}

