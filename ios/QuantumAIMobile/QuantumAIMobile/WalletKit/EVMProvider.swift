import Foundation

public final class EVMProvider {
    private let nodeURL: URL
    private let sync: SyncClient

    public init(nodeURL: URL, sync: SyncClient) {
        self.nodeURL = nodeURL
        self.sync = sync
    }

    public func broadcast(signedHex: String) async -> Bool {
        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "method": "eth_sendRawTransaction",
            "params": ["0x" + signedHex]
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return false }
        return await sync.post(nodeURL, body: body, key: "EVM_TX_" + UUID().uuidString)
    }
}
