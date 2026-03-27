import Foundation

public final class BitcoinProvider {
    private let baseURL: URL

    public init(baseURL: URL = URL(string: "https://blockstream.info/api")!) {
        self.baseURL = baseURL
    }

    public func broadcast(rawTransaction: String) async -> Bool {
        let url = baseURL.appendingPathComponent("tx")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = Data(rawTransaction.utf8)
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return (200..<300).contains(http.statusCode)
        } catch {
            return false
        }
    }
}
