import Combine
import Foundation
#if canImport(PassKit)
import PassKit
#endif

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

    public func processApplePay(amount: Double) {
        #if canImport(PassKit)
        let request = PKPaymentRequest()
        request.merchantIdentifier = "merchant.bursa.quantumai"
        request.supportedNetworks = [.visa, .masterCard]
        request.paymentSummaryItems = [
            PKPaymentSummaryItem(label: "QAI Asset Purchase", amount: NSDecimalNumber(value: amount))
        ]
        print("[APPLE-PAY] Odeme sayfasi hazirlandi: \(request.paymentSummaryItems.count) kalem")
        #else
        print("[APPLE-PAY] PassKit bu platformda kullanilamiyor. Tutar: \(amount)")
        #endif
    }
}
