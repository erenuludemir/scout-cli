import Combine
import Foundation

@MainActor
public final class BursaNetworkEngine: ObservableObject {
    public static let shared = BursaNetworkEngine()
    private var cancellables = Set<AnyCancellable>()
    private var webSocketTask: URLSessionWebSocketTask?

    @Published public var btcPrice: Double = 0.0

    public init() {}

    public func startPriceStream() {
        guard webSocketTask == nil else { return }
        guard let socketURL = URL(string: "wss://bursa-hq.quantumai.local/v1/ws") else { return }
        let webSocketTask = URLSession.shared.webSocketTask(with: socketURL)
        self.webSocketTask = webSocketTask
        webSocketTask.resume()
    }

    public func stopPriceStream() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
    }

    public func prepareFreeAccessState() {
        print("[ACCESS] Free of charge build active. No payment sheet is required.")
    }
}
