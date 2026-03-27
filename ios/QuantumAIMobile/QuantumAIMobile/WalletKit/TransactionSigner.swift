import Foundation

public enum WalletNetworkFamily: String, CaseIterable, Identifiable, Sendable {
    case evm
    case tron
    case solana
    case bitcoin

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .evm:
            return "EVM"
        case .tron:
            return "TRON"
        case .solana:
            return "Solana"
        case .bitcoin:
            return "Bitcoin"
        }
    }
}

public struct WalletNetwork: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let symbol: String
    public let family: WalletNetworkFamily
    public let chainID: Int?
    public let explorerBaseURL: URL?

    public init(id: String, name: String, symbol: String, family: WalletNetworkFamily, chainID: Int? = nil, explorerBaseURL: URL? = nil) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.family = family
        self.chainID = chainID
        self.explorerBaseURL = explorerBaseURL
    }
}

public enum WalletChainRegistry {
    private static let aliasMap: [String: String] = [
        "1": "ethereum",
        "eth": "ethereum",
        "8453": "base",
        "42161": "arbitrum",
        "arb": "arbitrum",
        "10": "optimism",
        "op": "optimism",
        "137": "polygon",
        "matic": "polygon",
        "56": "bsc",
        "bnb": "bsc",
        "43114": "avalanche",
        "avax": "avalanche",
        "59144": "linea",
        "81457": "blast",
        "534352": "scroll",
        "324": "zksync",
        "trc20": "tron",
        "trx": "tron",
        "sol": "solana",
        "btc": "bitcoin"
    ]

    private static let networks: [WalletNetwork] = [
        WalletNetwork(id: "ethereum", name: "Ethereum", symbol: "ETH", family: .evm, chainID: 1, explorerBaseURL: URL(string: "https://etherscan.io")),
        WalletNetwork(id: "base", name: "Base", symbol: "ETH", family: .evm, chainID: 8453, explorerBaseURL: URL(string: "https://basescan.org")),
        WalletNetwork(id: "arbitrum", name: "Arbitrum", symbol: "ETH", family: .evm, chainID: 42161, explorerBaseURL: URL(string: "https://arbiscan.io")),
        WalletNetwork(id: "optimism", name: "Optimism", symbol: "ETH", family: .evm, chainID: 10, explorerBaseURL: URL(string: "https://optimistic.etherscan.io")),
        WalletNetwork(id: "polygon", name: "Polygon", symbol: "MATIC", family: .evm, chainID: 137, explorerBaseURL: URL(string: "https://polygonscan.com")),
        WalletNetwork(id: "bsc", name: "BNB Smart Chain", symbol: "BNB", family: .evm, chainID: 56, explorerBaseURL: URL(string: "https://bscscan.com")),
        WalletNetwork(id: "avalanche", name: "Avalanche", symbol: "AVAX", family: .evm, chainID: 43114, explorerBaseURL: URL(string: "https://snowtrace.io")),
        WalletNetwork(id: "linea", name: "Linea", symbol: "ETH", family: .evm, chainID: 59144, explorerBaseURL: URL(string: "https://lineascan.build")),
        WalletNetwork(id: "blast", name: "Blast", symbol: "ETH", family: .evm, chainID: 81457, explorerBaseURL: URL(string: "https://blastscan.io")),
        WalletNetwork(id: "scroll", name: "Scroll", symbol: "ETH", family: .evm, chainID: 534352, explorerBaseURL: URL(string: "https://scrollscan.com")),
        WalletNetwork(id: "zksync", name: "zkSync Era", symbol: "ETH", family: .evm, chainID: 324, explorerBaseURL: URL(string: "https://era.zksync.network")),
        WalletNetwork(id: "tron", name: "TRON", symbol: "TRX", family: .tron, explorerBaseURL: URL(string: "https://tronscan.org")),
        WalletNetwork(id: "solana", name: "Solana", symbol: "SOL", family: .solana, explorerBaseURL: URL(string: "https://solscan.io")),
        WalletNetwork(id: "bitcoin", name: "Bitcoin", symbol: "BTC", family: .bitcoin, explorerBaseURL: URL(string: "https://mempool.space"))
    ]

    public static var defaultNetwork: WalletNetwork {
        networks[0]
    }

    public static func supportedNetworks(family: WalletNetworkFamily? = nil) -> [WalletNetwork] {
        if let family {
            return networks.filter { $0.family == family }
        }
        return networks
    }

    public static func network(id: String) -> WalletNetwork? {
        let resolved = aliasMap[id.lowercased()] ?? id.lowercased()
        return networks.first { $0.id == resolved }
    }
}
