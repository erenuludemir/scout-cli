import Foundation

public final class TRONProvider {
    private let baseURL: URL
    private let sync: SyncClient

    public init(baseURL: URL = URL(string: "https://api.trongrid.io")!, sync: SyncClient) {
        self.baseURL = baseURL
        self.sync = sync
    }

    public func broadcast(transactionData: Data) async -> Bool {
        let url = baseURL.appendingPathComponent("wallet/broadcasttransaction")
        return await sync.post(url, body: transactionData, key: "TRON_TX_" + UUID().uuidString)
    }
}
