import Foundation
import OSLog

public struct CoinMarketSnapshot: Equatable, Sendable {
    public let symbol: String
    public let assetName: String
    public let slug: String
    public let priceUSD: Double
    public let rank: Int?
    public let marketCapUSD: Double?
    public let volume24hUSD: Double?
    public let fullyDilutedMarketCapUSD: Double?
    public let circulatingSupply: Double?
    public let maxSupply: Double?
    public let watchCount: Int?
    public let updatedAt: Date?
    public let sourceURL: URL
}

@MainActor
public final class CoinMarketCapBridgeService: ObservableObject {
    @Published public private(set) var snapshot: CoinMarketSnapshot?
    @Published public private(set) var lastError: String?
    @Published public private(set) var isLoading = false
    @Published public private(set) var lastRefreshAt: Date?

    private let session: URLSession
    private var refreshTask: Task<Void, Never>?
    private var currentSymbol = "BTCUSDT"

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func startIfNeeded(symbol: String) {
        currentSymbol = symbol
        guard refreshTask == nil else { return }
        refreshTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refreshNow()
                try? await Task.sleep(for: .seconds(90))
            }
        }
    }

    public func reconfigure(symbol: String) {
        let symbolChanged = currentSymbol != symbol
        currentSymbol = symbol
        if refreshTask == nil {
            startIfNeeded(symbol: symbol)
        } else if symbolChanged {
            Task { [weak self] in
                await self?.refreshNow()
            }
        }
    }

    public func stop() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    public func bridgeURL(for tradingPair: String) -> URL {
        let baseSymbol = Self.baseSymbol(for: tradingPair)
        let slug = Self.slug(for: tradingPair)
        let path = slug.isEmpty ? baseSymbol.lowercased() : slug
        return URL(string: "https://coinmarketcap.com/currencies/\(path)/")!
    }

    public func refreshNow() async {
        guard !isLoading else { return }

        let interval: Any? = {
            if #available(iOS 15.0, macOS 12.0, *) {
                return QAISignpost.begin("CMC Refresh")
            }
            return nil
        }()
        isLoading = true
        defer {
            isLoading = false
            if #available(iOS 15.0, macOS 12.0, *), let interval = interval as? OSSignpostIntervalState {
                QAISignpost.end("CMC Refresh", interval)
            }
        }

        let symbol = currentSymbol
        let url = bridgeURL(for: symbol)
        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        request.timeoutInterval = 20

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                lastError = "CoinMarketCap köprüsü yanıt vermedi"
                return
            }
            guard let html = String(data: data, encoding: .utf8) else {
                lastError = "CoinMarketCap içeriği çözümlenemedi"
                return
            }

            snapshot = try Self.parseSnapshot(from: html, tradingPair: symbol, sourceURL: url)
            lastRefreshAt = .now
            lastError = nil
            if #available(iOS 15.0, macOS 12.0, *) {
                QAISignpost.event("CMC Snapshot Ready", message: "symbol=\(symbol)")
            }
        } catch {
            lastError = "CoinMarketCap köprüsü hatası: \(error.localizedDescription)"
            if #available(iOS 15.0, macOS 12.0, *) {
                QAISignpost.event("CMC Snapshot Failed", message: "symbol=\(symbol)")
            }
        }
    }

    deinit {
        refreshTask?.cancel()
    }

    private static func parseSnapshot(from html: String, tradingPair: String, sourceURL: URL) throws -> CoinMarketSnapshot {
        let baseSymbol = baseSymbol(for: tradingPair)
        let slug = slug(for: tradingPair)
        let prefix = "\"symbol\":\"\(baseSymbol)\",\"slug\":\"\(slug)\""

        guard let prefixRange = html.range(of: prefix) else {
            throw NSError(domain: "CoinMarketCapBridgeService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Seçili sembol CoinMarketCap sayfasında bulunamadı"])
        }

        let blockEndIndex = html.index(prefixRange.lowerBound, offsetBy: min(18_000, html.distance(from: prefixRange.lowerBound, to: html.endIndex)), limitedBy: html.endIndex) ?? html.endIndex
        let block = String(html[prefixRange.lowerBound..<blockEndIndex])
        let title = firstMatch(in: html, pattern: #"<title>(.*?) price today"#) ?? slug.capitalized

        let price = firstDouble(in: block, pattern: #""priceChange":\{"price":([0-9.]+)"#)
            ?? firstDouble(in: block, pattern: #""price":([0-9.]+)"#)
            ?? 0
        let rank = firstInt(in: block, pattern: #""rank":([0-9]+)"#)
        let marketCap = firstDouble(in: block, pattern: #""marketCap":([0-9.]+)"#)
        let volume24h = firstDouble(in: block, pattern: #""volume24h":([0-9.]+)"#)
        let fdv = firstDouble(in: block, pattern: #""fullyDilutedMarketCap":([0-9.]+)"#)
        let circulatingSupply = firstDouble(in: block, pattern: #""circulatingSupply":([0-9.]+)"#)
        let maxSupply = firstDouble(in: block, pattern: #""maxSupply":([0-9.]+)"#)
        let watchCount = firstInt(in: block, pattern: #""watchCount":"?([0-9]+)"?"#)
        let updatedAt = firstDate(in: block, pattern: #""latestUpdateTime":"([^"]+)""#)

        return CoinMarketSnapshot(
            symbol: tradingPair,
            assetName: decodeEntities(title),
            slug: slug,
            priceUSD: price,
            rank: rank,
            marketCapUSD: marketCap,
            volume24hUSD: volume24h,
            fullyDilutedMarketCapUSD: fdv,
            circulatingSupply: circulatingSupply,
            maxSupply: maxSupply,
            watchCount: watchCount,
            updatedAt: updatedAt,
            sourceURL: sourceURL
        )
    }

    static func slug(for tradingPair: String) -> String {
        switch tradingPair.uppercased() {
        case "BTCUSDT":
            return "bitcoin"
        case "ETHUSDT":
            return "ethereum"
        case "BNBUSDT":
            return "bnb"
        case "SOLUSDT":
            return "solana"
        default:
            return baseSymbol(for: tradingPair).lowercased()
        }
    }

    static func baseSymbol(for tradingPair: String) -> String {
        if tradingPair.hasSuffix("USDT") {
            return String(tradingPair.dropLast(4))
        }
        return tradingPair.uppercased()
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = regex(for: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range), let group = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[group])
    }

    private static func firstDouble(in text: String, pattern: String) -> Double? {
        guard let value = firstMatch(in: text, pattern: pattern) else { return nil }
        return Double(value)
    }

    private static func firstInt(in text: String, pattern: String) -> Int? {
        guard let value = firstMatch(in: text, pattern: pattern) else { return nil }
        return Int(value)
    }

    private static func firstDate(in text: String, pattern: String) -> Date? {
        guard let value = firstMatch(in: text, pattern: pattern) else { return nil }
        return iso8601Formatter.date(from: value)
    }

    private static func decodeEntities(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
    }

    private static func regex(for pattern: String) -> NSRegularExpression? {
        if let cached = regexCache[pattern] {
            return cached
        }

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) else {
            return nil
        }

        regexCache[pattern] = regex
        return regex
    }

    private static let iso8601Formatter = ISO8601DateFormatter()
    private static var regexCache: [String: NSRegularExpression] = [:]
}
