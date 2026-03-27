import Foundation

public final class BinanceAdapter {
    enum Endpoint: CaseIterable {
        case marketDataVision
        case stream443
        case stream9443

        var label: String {
            switch self {
            case .marketDataVision:
                return "Binance Vision"
            case .stream443:
                return "Binance 443"
            case .stream9443:
                return "Binance 9443"
            }
        }

        func url(for symbol: String) -> URL? {
            switch self {
            case .marketDataVision:
                return URL(string: "wss://data-stream.binance.vision/ws/\(symbol)@aggTrade")
            case .stream443:
                return URL(string: "wss://stream.binance.com:443/ws/\(symbol)@aggTrade")
            case .stream9443:
                return URL(string: "wss://stream.binance.com:9443/ws/\(symbol)@aggTrade")
            }
        }
    }

    private let symbol: String
    private let onTick: (Tick) -> Void
    private let onDisconnect: ((String) -> Void)?
    private let endpoint: Endpoint
    
    init(symbol: String = "BTCUSDT", endpoint: Endpoint = .marketDataVision, callback: @escaping (Tick) -> Void, onDisconnect: ((String) -> Void)? = nil) {
        self.symbol = symbol.lowercased()
        self.endpoint = endpoint
        self.onTick = callback
        self.onDisconnect = onDisconnect
    }

    public func connect() {
        guard let url = endpoint.url(for: symbol) else {
            onDisconnect?("Binance websocket adresi kurulamadı.")
            return
        }

        MarketWebSocketClient.shared.connect(url: url) { [weak self] jsonString in
            guard let tick = Self.parseTick(from: jsonString) else { return }
            self?.onTick(tick)
        } onDisconnect: { [weak self] error in
            let fallbackLabel = self?.endpoint.label ?? "Binance"
            let message = error.map { "\(fallbackLabel) websocket kesildi: \($0.localizedDescription)" } ?? "\(fallbackLabel) websocket bağlantısı kapandı."
            self?.onDisconnect?(message)
        }
    }

    public func disconnect() {
        MarketWebSocketClient.shared.disconnect()
    }
    
    deinit {
        disconnect()
    }

    static func parseTick(from jsonString: String) -> Tick? {
        guard
            let data = jsonString.data(using: .utf8),
            let payload = try? JSONDecoder().decode(BinanceAggTradePayload.self, from: data),
            let price = Double(payload.price),
            let volume = Double(payload.volume)
        else {
            return nil
        }

        let eventMillis = payload.tradeTime ?? payload.eventTime ?? (Date().timeIntervalSince1970 * 1_000)
        let timestamp = Date(timeIntervalSince1970: eventMillis / 1_000)
        return Tick(ts: timestamp, price: price, vol: volume)
    }
}

private struct BinanceAggTradePayload: Decodable {
    let symbol: String?
    let price: String
    let volume: String
    let tradeTime: TimeInterval?
    let eventTime: TimeInterval?

    private enum CodingKeys: String, CodingKey {
        case symbol = "s"
        case price = "p"
        case volume = "q"
        case tradeTime = "T"
        case eventTime = "E"
    }
}
