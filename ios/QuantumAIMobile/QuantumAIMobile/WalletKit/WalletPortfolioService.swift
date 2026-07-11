import Foundation

public enum WalletAddressOrigin: String, Sendable {
    case configured = "Configured"
    case derived = "Derived"
}

public enum WalletSnapshotOrigin: String, Sendable {
    case backend = "Gateway"
    case direct = "Live RPC"
    case hybrid = "Gateway + RPC"
    case unavailable = "Offline"
}

public struct WalletNetworkBalance: Identifiable, Equatable, Sendable {
    public let network: WalletNetwork
    public let address: String
    public let addressOrigin: WalletAddressOrigin
    public let balance: Decimal?
    public let quoteUSD: Double?
    public let valueUSD: Double?
    public let origin: WalletSnapshotOrigin
    public let error: String?

    public var id: String { network.id }
    public var isLive: Bool { balance != nil && error == nil }
}

@MainActor
public final class WalletPortfolioService: ObservableObject {
    @Published public private(set) var selectedNetworkID = WalletChainRegistry.defaultNetwork.id
    @Published public private(set) var snapshots: [String: WalletNetworkBalance] = [:]
    @Published public private(set) var totalEquityUSD: Double = 0
    @Published public private(set) var isLoading = false
    @Published public private(set) var lastError: String?
    @Published public private(set) var lastRefreshAt: Date?
    @Published public private(set) var dataSourceSummary = WalletSnapshotOrigin.unavailable.rawValue

    private let session: URLSession
    private var configuration: LiveOpsConfiguration
    private var lastRefreshInput: RefreshInput?
    private var refreshTask: Task<Void, Never>?
    private var hasStarted = false
    private var isSceneActive = true

    public init(
        session: URLSession = .shared,
        configuration: LiveOpsConfiguration = .load()
    ) {
        self.session = session
        self.configuration = configuration
    }

    public var totalEquityText: String {
        Self.usdString(totalEquityUSD)
    }

    public var selectedSnapshot: WalletNetworkBalance? {
        snapshots[selectedNetworkID]
    }

    public var liveCoverage: Double {
        guard let input = lastRefreshInput, !input.networks.isEmpty else { return 0 }
        let liveCount = input.networks.filter { snapshots[$0.id]?.isLive == true }.count
        return Double(liveCount) / Double(input.networks.count)
    }

    public var failedSnapshotCount: Int {
        snapshots.values.filter { $0.error != nil }.count
    }

    public var recoveredNetworkCount: Int {
        snapshots.values.filter { $0.origin == .hybrid }.count
    }

    public var lastRefreshDescription: String {
        guard let lastRefreshAt else { return "Bekleniyor" }
        return Self.relativeFormatter.localizedString(for: lastRefreshAt, relativeTo: .now)
    }

    public func startIfNeeded(
        selectedNetworkID: String,
        walletService: WalletService,
        networks: [WalletNetwork]
    ) {
        hasStarted = true
        reconfigure(selectedNetworkID: selectedNetworkID, walletService: walletService, networks: networks)
    }

    public func reconfigure(
        selectedNetworkID: String,
        walletService: WalletService,
        networks: [WalletNetwork]
    ) {
        configuration = .load()
        let input = buildRefreshInput(
            selectedNetworkID: selectedNetworkID,
            walletService: walletService,
            networks: networks
        )
        self.selectedNetworkID = input.selectedNetworkID
        lastRefreshInput = input

        guard isSceneActive else { return }

        if refreshTask == nil {
            startRefreshLoopIfNeeded()
        } else {
            Task { [weak self] in
                await self?.refreshNow()
            }
        }
    }

    public func pauseForInactiveScene() {
        isSceneActive = false
        refreshTask?.cancel()
        refreshTask = nil
    }

    public func refreshForActiveScene() {
        isSceneActive = true
        guard hasStarted else { return }
        startRefreshLoopIfNeeded()
    }

    public func refreshNow() async {
        guard isSceneActive else { return }
        guard !isLoading else { return }
        guard let input = lastRefreshInput else { return }

        isLoading = true
        defer { isLoading = false }

        let result = await fetchPortfolio(using: input)
        selectedNetworkID = input.selectedNetworkID
        snapshots = Dictionary(uniqueKeysWithValues: result.snapshots.map { ($0.network.id, $0) })
        totalEquityUSD = result.snapshots.compactMap(\.valueUSD).reduce(0, +)
        dataSourceSummary = result.dataSourceSummary.rawValue
        lastError = result.lastError
        lastRefreshAt = .now
    }

    public func resolvedAddress(for networkID: String) -> String? {
        snapshots[networkID]?.address ?? lastRefreshInput?.addressBook[networkID]
    }

    public func addressOrigin(for networkID: String) -> WalletAddressOrigin? {
        snapshots[networkID]?.addressOrigin ?? lastRefreshInput?.addressOrigins[networkID]
    }

    public static func usdString(_ value: Double?) -> String {
        guard let value else { return "—" }
        return currencyFormatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }

    public static func assetString(_ balance: Decimal?, symbol: String) -> String {
        guard let balance else { return "—" }
        let numeric = NSDecimalNumber(decimal: balance).doubleValue
        let rendered = assetFormatter.string(from: NSNumber(value: numeric)) ?? "0"
        return rendered + " " + symbol
    }

    private func startRefreshLoopIfNeeded() {
        guard refreshTask == nil else { return }
        refreshTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refreshNow()
                try? await Task.sleep(for: .seconds(75))
            }
        }
    }

    private func buildRefreshInput(
        selectedNetworkID: String,
        walletService: WalletService,
        networks: [WalletNetwork]
    ) -> RefreshInput {
        let normalizedSelected = WalletChainRegistry.network(id: selectedNetworkID)?.id ?? configuration.preferredWalletNetworkID
        var addressBook = configuration.walletAddresses
        var addressOrigins: [String: WalletAddressOrigin] = configuration.walletAddresses.keys.reduce(into: [:]) { partialResult, key in
            partialResult[key.lowercased()] = .configured
        }

        for network in networks {
            if let configured = configuredAddress(for: network, in: addressBook) {
                addressBook[network.id] = configured
                addressOrigins[network.id] = .configured
            } else if let derived = try? walletService.address(for: network) {
                addressBook[network.id] = derived
                addressOrigins[network.id] = .derived
            }

            if network.family == .evm, let evmAddress = addressBook[network.id], addressBook["evm"] == nil {
                addressBook["evm"] = evmAddress
                addressOrigins["evm"] = addressOrigins[network.id] ?? .derived
            }
        }

        if addressBook["default"] == nil {
            let defaultAddress = addressBook[normalizedSelected] ?? addressBook["evm"] ?? addressBook[WalletChainRegistry.defaultNetwork.id]
            if let defaultAddress {
                addressBook["default"] = defaultAddress
                addressOrigins["default"] = addressOrigins[normalizedSelected] ?? addressOrigins["evm"] ?? .derived
            }
        }

        return RefreshInput(
            selectedNetworkID: normalizedSelected,
            networks: networks,
            addressBook: addressBook,
            addressOrigins: addressOrigins,
            liveEndpoints: configuration.liveEndpoints
        )
    }

    private func configuredAddress(for network: WalletNetwork, in addressBook: [String: String]) -> String? {
        let candidates = [
            addressBook[network.id],
            addressBook[network.family.rawValue],
            network.family == .evm ? addressBook["ethereum"] : nil,
            addressBook["default"],
        ]
        return candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }

    private func fetchPortfolio(using input: RefreshInput) async -> FetchResult {
        async let gatewayResult = fetchGatewayPortfolio(using: input)
        async let quotes = fetchQuotes(for: Set(input.networks.map(\.symbol)))

        let resolvedGateway = await gatewayResult
        let resolvedQuotes = await quotes
        let fallbackIDs = input.networks
            .filter { resolvedGateway.snapshots[$0.id] == nil }
            .map(\.id)
        let fallbackResults = await fetchDirectBalances(for: fallbackIDs, using: input)

        let snapshots = input.networks.map { network in
            let address = input.addressBook[network.id] ?? "—"
            let addressOrigin = input.addressOrigins[network.id] ?? .derived
            let quote = resolvedQuotes[network.symbol.uppercased()]

            if let gatewaySnapshot = resolvedGateway.snapshots[network.id] {
                let valueUSD = quote.map { gatewaySnapshot.balance.doubleValue * $0 }
                return WalletNetworkBalance(
                    network: network,
                    address: gatewaySnapshot.address,
                    addressOrigin: addressOrigin,
                    balance: gatewaySnapshot.balance,
                    quoteUSD: quote,
                    valueUSD: valueUSD,
                    origin: .backend,
                    error: nil
                )
            }

            if let fallbackSnapshot = fallbackResults.snapshots[network.id] {
                let valueUSD = quote.map { fallbackSnapshot.balance.doubleValue * $0 }
                let origin: WalletSnapshotOrigin = resolvedGateway.snapshots.isEmpty ? .direct : .hybrid
                return WalletNetworkBalance(
                    network: network,
                    address: fallbackSnapshot.address,
                    addressOrigin: addressOrigin,
                    balance: fallbackSnapshot.balance,
                    quoteUSD: quote,
                    valueUSD: valueUSD,
                    origin: origin,
                    error: nil
                )
            }

            let error = resolvedGateway.errors[network.id] ?? fallbackResults.errors[network.id] ?? "Canlı bakiye alınamadı"
            return WalletNetworkBalance(
                network: network,
                address: address,
                addressOrigin: addressOrigin,
                balance: nil,
                quoteUSD: quote,
                valueUSD: nil,
                origin: .unavailable,
                error: error
            )
        }

        let dataSourceSummary: WalletSnapshotOrigin
        if !resolvedGateway.snapshots.isEmpty && !fallbackResults.snapshots.isEmpty {
            dataSourceSummary = .hybrid
        } else if !resolvedGateway.snapshots.isEmpty {
            dataSourceSummary = .backend
        } else if !fallbackResults.snapshots.isEmpty {
            dataSourceSummary = .direct
        } else {
            dataSourceSummary = .unavailable
        }

        let lastError = snapshots.contains(where: \.isLive) ? nil : snapshots.compactMap(\.error).first
        return FetchResult(
            snapshots: snapshots,
            lastError: lastError,
            dataSourceSummary: dataSourceSummary
        )
    }

    private func fetchGatewayPortfolio(using input: RefreshInput) async -> GatewayFetchResult {
        guard !input.liveEndpoints.isEmpty else {
            return GatewayFetchResult(snapshots: [:], errors: [:])
        }

        let payload: [String: Any] = [
            "addresses": input.addressBook,
            "networks": input.networks.map(\.id),
        ]

        guard let body = try? JSONSerialization.data(withJSONObject: payload) else {
            return GatewayFetchResult(snapshots: [:], errors: [:])
        }

        for endpoint in input.liveEndpoints {
            let url = endpoint.appendingPathComponent("wallet/portfolio")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 20

            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    continue
                }
                let envelope = try JSONDecoder().decode(GatewayEnvelope.self, from: data)
                let snapshots = envelope.result.results.reduce(into: [String: RawBalanceSnapshot]()) { partialResult, item in
                    guard item.ok, let balancePayload = item.balance else { return }
                    let networkID = item.network.lowercased()
                    guard let network = WalletChainRegistry.network(id: networkID),
                          let balance = Decimal(string: balancePayload.balance, locale: Self.posixLocale)
                    else {
                        return
                    }
                    let address = balancePayload.address.isEmpty ? (input.addressBook[networkID] ?? "—") : balancePayload.address
                    partialResult[networkID] = RawBalanceSnapshot(network: network, address: address, balance: balance)
                }
                let errors = envelope.result.results.reduce(into: [String: String]()) { partialResult, item in
                    guard !item.ok, let error = item.error else { return }
                    partialResult[item.network.lowercased()] = error
                }
                if !snapshots.isEmpty {
                    return GatewayFetchResult(snapshots: snapshots, errors: errors)
                }
            } catch {
                continue
            }
        }

        return GatewayFetchResult(snapshots: [:], errors: [:])
    }

    private func fetchDirectBalances(
        for networkIDs: [String],
        using input: RefreshInput
    ) async -> DirectFetchResult {
        await withTaskGroup(of: (String, Result<RawBalanceSnapshot, Error>).self) { group in
            for networkID in networkIDs {
                guard let network = WalletChainRegistry.network(id: networkID),
                      let address = input.addressBook[networkID]
                else {
                    continue
                }

                group.addTask { [session] in
                    do {
                        let snapshot = try await Self.fetchDirectBalance(
                            session: session,
                            network: network,
                            address: address
                        )
                        return (network.id, .success(snapshot))
                    } catch {
                        return (network.id, .failure(error))
                    }
                }
            }

            var snapshots: [String: RawBalanceSnapshot] = [:]
            var errors: [String: String] = [:]

            for await (networkID, result) in group {
                switch result {
                case let .success(snapshot):
                    snapshots[networkID] = snapshot
                case let .failure(error):
                    errors[networkID] = error.localizedDescription
                }
            }

            return DirectFetchResult(snapshots: snapshots, errors: errors)
        }
    }

    private func fetchQuotes(for symbols: Set<String>) async -> [String: Double] {
        await withTaskGroup(of: (String, Double?).self) { group in
            for symbol in symbols {
                group.addTask { [session] in
                    let quote = await Self.fetchQuoteUSD(session: session, assetSymbol: symbol)
                    return (symbol.uppercased(), quote)
                }
            }

            var resolved: [String: Double] = [:]
            for await (symbol, quote) in group {
                if let quote {
                    resolved[symbol] = quote
                }
            }
            return resolved
        }
    }

    private static func fetchQuoteUSD(
        session: URLSession,
        assetSymbol: String
    ) async -> Double? {
        let normalized = assetSymbol.uppercased()
        if let binanceURL = URL(string: "https://api.binance.com/api/v3/ticker/price?symbol=\(normalized)USDT"),
           let price = await loadQuote(from: binanceURL, session: session, keyPath: ["price"])
        {
            return price
        }
        if let coinbaseURL = URL(string: "https://api.coinbase.com/v2/prices/\(normalized)-USD/spot"),
           let price = await loadQuote(from: coinbaseURL, session: session, keyPath: ["data", "amount"])
        {
            return price
        }
        return nil
    }

    private static func loadQuote(
        from url: URL,
        session: URLSession,
        keyPath: [String]
    ) async -> Double? {
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            let json = try JSONSerialization.jsonObject(with: data)
            return extractDouble(json, keyPath: keyPath)
        } catch {
            return nil
        }
    }

    private static func extractDouble(_ json: Any, keyPath: [String]) -> Double? {
        var cursor: Any = json
        for key in keyPath {
            guard let dictionary = cursor as? [String: Any], let next = dictionary[key] else {
                return nil
            }
            cursor = next
        }
        if let value = cursor as? NSNumber {
            return value.doubleValue
        }
        if let value = cursor as? String {
            return Double(value)
        }
        return nil
    }

    private static func fetchDirectBalance(
        session: URLSession,
        network: WalletNetwork,
        address: String
    ) async throws -> RawBalanceSnapshot {
        switch network.family {
        case .evm:
            guard let rpcURL = evmPublicRPCURLs[network.id] else {
                throw NSError(domain: "WalletPortfolioService", code: 1, userInfo: [NSLocalizedDescriptionKey: "EVM RPC bulunamadı"])
            }
            let payload: [String: Any] = [
                "jsonrpc": "2.0",
                "id": 1,
                "method": "eth_getBalance",
                "params": [address, "latest"],
            ]
            let data = try JSONSerialization.data(withJSONObject: payload)
            var request = URLRequest(url: rpcURL)
            request.httpMethod = "POST"
            request.httpBody = data
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let (responseData, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw NSError(domain: "WalletPortfolioService", code: 2, userInfo: [NSLocalizedDescriptionKey: "EVM bakiye yanıtı başarısız"])
            }
            let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any]
            guard let result = json?["result"] as? String else {
                throw NSError(domain: "WalletPortfolioService", code: 3, userInfo: [NSLocalizedDescriptionKey: "EVM bakiye verisi yok"])
            }
            let wei = Int(result.replacingOccurrences(of: "0x", with: ""), radix: 16) ?? 0
            return RawBalanceSnapshot(
                network: network,
                address: address,
                balance: Decimal(wei) / pow(10, 18)
            )

        case .tron:
            guard let url = URL(string: "https://api.trongrid.io/v1/accounts/\(address)") else {
                throw NSError(domain: "WalletPortfolioService", code: 4, userInfo: [NSLocalizedDescriptionKey: "TRON endpoint çözümlenemedi"])
            }
            let (responseData, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw NSError(domain: "WalletPortfolioService", code: 5, userInfo: [NSLocalizedDescriptionKey: "TRON bakiye yanıtı başarısız"])
            }
            let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any]
            let account = ((json?["data"] as? [[String: Any]])?.first) ?? [:]
            let sun = (account["balance"] as? NSNumber)?.intValue ?? 0
            return RawBalanceSnapshot(
                network: network,
                address: address,
                balance: Decimal(sun) / pow(10, 6)
            )

        case .solana:
            guard let rpcURL = URL(string: "https://api.mainnet-beta.solana.com") else {
                throw NSError(domain: "WalletPortfolioService", code: 6, userInfo: [NSLocalizedDescriptionKey: "Solana RPC çözümlenemedi"])
            }
            let payload: [String: Any] = [
                "jsonrpc": "2.0",
                "id": 1,
                "method": "getBalance",
                "params": [address],
            ]
            let data = try JSONSerialization.data(withJSONObject: payload)
            var request = URLRequest(url: rpcURL)
            request.httpMethod = "POST"
            request.httpBody = data
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let (responseData, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw NSError(domain: "WalletPortfolioService", code: 7, userInfo: [NSLocalizedDescriptionKey: "Solana bakiye yanıtı başarısız"])
            }
            let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any]
            let result = json?["result"] as? [String: Any]
            let lamports = (result?["value"] as? NSNumber)?.intValue ?? 0
            return RawBalanceSnapshot(
                network: network,
                address: address,
                balance: Decimal(lamports) / pow(10, 9)
            )

        case .bitcoin:
            guard let url = URL(string: "https://blockstream.info/api/address/\(address)") else {
                throw NSError(domain: "WalletPortfolioService", code: 8, userInfo: [NSLocalizedDescriptionKey: "Bitcoin endpoint çözümlenemedi"])
            }
            let (responseData, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw NSError(domain: "WalletPortfolioService", code: 9, userInfo: [NSLocalizedDescriptionKey: "Bitcoin bakiye yanıtı başarısız"])
            }
            let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any]
            let chainStats = json?["chain_stats"] as? [String: Any] ?? [:]
            let mempoolStats = json?["mempool_stats"] as? [String: Any] ?? [:]
            let chainFunded = (chainStats["funded_txo_sum"] as? NSNumber)?.intValue ?? 0
            let chainSpent = (chainStats["spent_txo_sum"] as? NSNumber)?.intValue ?? 0
            let mempoolFunded = (mempoolStats["funded_txo_sum"] as? NSNumber)?.intValue ?? 0
            let mempoolSpent = (mempoolStats["spent_txo_sum"] as? NSNumber)?.intValue ?? 0
            let sats = (chainFunded - chainSpent) + (mempoolFunded - mempoolSpent)
            return RawBalanceSnapshot(
                network: network,
                address: address,
                balance: Decimal(sats) / pow(10, 8)
            )
        }
    }

    private struct RefreshInput: Sendable {
        let selectedNetworkID: String
        let networks: [WalletNetwork]
        let addressBook: [String: String]
        let addressOrigins: [String: WalletAddressOrigin]
        let liveEndpoints: [URL]
    }

    private struct RawBalanceSnapshot: Sendable {
        let network: WalletNetwork
        let address: String
        let balance: Decimal
    }

    private struct FetchResult {
        let snapshots: [WalletNetworkBalance]
        let lastError: String?
        let dataSourceSummary: WalletSnapshotOrigin
    }

    private struct GatewayFetchResult {
        let snapshots: [String: RawBalanceSnapshot]
        let errors: [String: String]
    }

    private struct DirectFetchResult {
        let snapshots: [String: RawBalanceSnapshot]
        let errors: [String: String]
    }

    private struct GatewayEnvelope: Decodable {
        let ok: Bool
        let result: GatewayResult
    }

    private struct GatewayResult: Decodable {
        let ok: Bool?
        let results: [GatewayItem]
    }

    private struct GatewayItem: Decodable {
        let network: String
        let ok: Bool
        let error: String?
        let balance: GatewayBalance?
    }

    private struct GatewayBalance: Decodable {
        let address: String
        let balance: String
    }

    private static let posixLocale = Locale(identifier: "en_US_POSIX")

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    private static let assetFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 6
        return formatter
    }()

    private static let evmPublicRPCURLs: [String: URL] = [
        "ethereum": URL(string: "https://ethereum-rpc.publicnode.com")!,
        "base": URL(string: "https://base-rpc.publicnode.com")!,
        "arbitrum": URL(string: "https://arbitrum-one-rpc.publicnode.com")!,
        "optimism": URL(string: "https://optimism-rpc.publicnode.com")!,
        "polygon": URL(string: "https://polygon-bor-rpc.publicnode.com")!,
        "bsc": URL(string: "https://bsc-rpc.publicnode.com")!,
        "avalanche": URL(string: "https://avalanche-c-chain-rpc.publicnode.com")!,
        "linea": URL(string: "https://rpc.linea.build")!,
        "blast": URL(string: "https://rpc.blast.io")!,
        "scroll": URL(string: "https://rpc.scroll.io")!,
        "zksync": URL(string: "https://mainnet.era.zksync.io")!,
    ]
}

private extension Decimal {
    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}

private func pow(_ base: Int, _ exponent: Int) -> Decimal {
    var value = Decimal(1)
    for _ in 0..<exponent {
        value *= Decimal(base)
    }
    return value
}
