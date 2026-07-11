import Foundation

public enum WalletConnectorProvider: String, CaseIterable, Identifiable, Codable, Sendable {
    case binance
    case coinbase
    case trust
    case metamask

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .binance: return "Binance"
        case .coinbase: return "Coinbase Wallet"
        case .trust: return "Trust Wallet"
        case .metamask: return "MetaMask"
        }
    }

    public var summary: String {
        switch self {
        case .binance: return "Binance Spot cüzdanını aç, bakiye görünümünü doğrula ve bu ekrana geri dön."
        case .coinbase: return "Uygulamayı açıp bağlantı durumunu gözden geçir, sonra geri dön."
        case .trust: return "Harici onayı tamamlayıp uygulama içi doğrulamaya dön."
        case .metamask: return "Kurulum yerine yalnızca geri dönüş ve doğrulama yolunu kontrol et."
        }
    }

    public var activationURL: URL {
        switch self {
        case .binance:
            return URL(string: "https://www.binance.com/en/download")!
        case .coinbase:
            return URL(string: "https://go.cb-w.com/dapp?cb_url=https%3A%2F%2Fwww.coinbase.com%2Fwallet")!
        case .trust:
            return URL(string: "https://link.trustwallet.com/open_url?coin_id=60&url=https%3A%2F%2Ftrustwallet.com")!
        case .metamask:
            return URL(string: "https://metamask.io/download/")!
        }
    }
}

public enum WalletConnectorStatus: String, Codable, Sendable {
    case idle
    case activationStarted
    case verified
}

private struct WalletActivationSnapshot: Codable {
    var statuses: [String: WalletConnectorStatus]
    var lastVerifiedAt: [String: Date]
}

@MainActor
public final class WalletActivationStore: ObservableObject {
    private enum Key {
        static let snapshot = "qai.wallet.connector.snapshot"
    }

    private let defaults: UserDefaults

    @Published private var statuses: [String: WalletConnectorStatus] {
        didSet { persist() }
    }

    @Published private var lastVerifiedAt: [String: Date] {
        didSet { persist() }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if
            let raw = defaults.data(forKey: Key.snapshot),
            let snapshot = try? JSONDecoder().decode(WalletActivationSnapshot.self, from: raw)
        {
            statuses = snapshot.statuses
            lastVerifiedAt = snapshot.lastVerifiedAt
        } else {
            statuses = [:]
            lastVerifiedAt = [:]
        }
    }

    public func status(for provider: WalletConnectorProvider) -> WalletConnectorStatus {
        statuses[provider.rawValue] ?? .idle
    }

    public func verifiedAt(for provider: WalletConnectorProvider) -> Date? {
        lastVerifiedAt[provider.rawValue]
    }

    public var verifiedProviders: [WalletConnectorProvider] {
        WalletConnectorProvider.allCases.filter { status(for: $0) == .verified }
    }

    public func markActivationStarted(for provider: WalletConnectorProvider) {
        statuses[provider.rawValue] = .activationStarted
    }

    public func markVerified(for provider: WalletConnectorProvider) {
        statuses[provider.rawValue] = .verified
        lastVerifiedAt[provider.rawValue] = .now
    }

    public func reset(_ provider: WalletConnectorProvider) {
        statuses[provider.rawValue] = .idle
        lastVerifiedAt[provider.rawValue] = nil
    }

    private func persist() {
        let snapshot = WalletActivationSnapshot(statuses: statuses, lastVerifiedAt: lastVerifiedAt)
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: Key.snapshot)
        }
    }
}
