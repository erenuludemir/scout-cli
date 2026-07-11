import Foundation

public struct LiveOpsConfiguration: Equatable, Sendable {
    public static let managedConfigKey = "com.apple.configuration.managed"

    public let liveEndpoints: [URL]
    public let walletAddresses: [String: String]
    public let preferredWalletNetworkID: String

    public init(liveEndpoints: [URL], walletAddresses: [String: String], preferredWalletNetworkID: String) {
        self.liveEndpoints = liveEndpoints
        self.walletAddresses = walletAddresses
        self.preferredWalletNetworkID = preferredWalletNetworkID
    }

    public static func load(
        defaults: UserDefaults = .standard,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> LiveOpsConfiguration {
        let managed = defaults.dictionary(forKey: managedConfigKey) ?? [:]
        let rawEndpoints = readStringArray(
            key: "qai.live_endpoints",
            managed: managed,
            defaults: defaults,
            environmentValue: environment["QAI_LIVE_ENDPOINTS"]
        )
        let endpoints = uniqueURLs(from: rawEndpoints)

        var walletAddresses = normalizeAddressDictionary(
            readStringDictionary(
                key: "qai.wallet.addresses",
                managed: managed,
                defaults: defaults,
                environmentValue: environment["QAI_WALLET_ADDRESSES_JSON"]
            )
        )

        for network in WalletChainRegistry.supportedNetworks() {
            let envKey = "QAI_WALLET_" + network.id.uppercased().replacingOccurrences(of: "-", with: "_") + "_ADDRESS"
            if let value = environment[envKey], !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                walletAddresses[network.id] = value.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        if let evmAddress = firstNonEmpty([
            environment["ETH_ADDRESS"],
            environment["WALLET_ADDRESS"],
            walletAddresses["ethereum"],
            walletAddresses["evm"],
        ]) {
            walletAddresses["ethereum"] = walletAddresses["ethereum"] ?? evmAddress
            walletAddresses["evm"] = walletAddresses["evm"] ?? evmAddress
        }

        let preferredRaw = readStringValue(
            key: "qai.wallet.default_network",
            managed: managed,
            defaults: defaults,
            environmentValue: environment["QAI_WALLET_DEFAULT_NETWORK"]
        )
        let preferredWalletNetworkID = WalletChainRegistry.network(id: preferredRaw ?? "")?.id ?? WalletChainRegistry.defaultNetwork.id

        return LiveOpsConfiguration(
            liveEndpoints: endpoints,
            walletAddresses: walletAddresses,
            preferredWalletNetworkID: preferredWalletNetworkID
        )
    }

    private static func readStringArray(
        key: String,
        managed: [String: Any],
        defaults: UserDefaults,
        environmentValue: String?
    ) -> [String] {
        if let managedValues = managed[key] as? [String], !managedValues.isEmpty {
            return managedValues
        }
        if let defaultsValues = defaults.array(forKey: key) as? [String], !defaultsValues.isEmpty {
            return defaultsValues
        }
        if let environmentValue, !environmentValue.isEmpty {
            if let data = environmentValue.data(using: .utf8),
               let decoded = try? JSONDecoder().decode([String].self, from: data),
               !decoded.isEmpty
            {
                return decoded
            }
            return environmentValue
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        return []
    }

    private static func readStringDictionary(
        key: String,
        managed: [String: Any],
        defaults: UserDefaults,
        environmentValue: String?
    ) -> [String: String] {
        if let managedValues = managed[key] as? [String: String], !managedValues.isEmpty {
            return managedValues
        }
        if let defaultsValues = defaults.dictionary(forKey: key) as? [String: String], !defaultsValues.isEmpty {
            return defaultsValues
        }
        if let environmentValue, let data = environmentValue.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data),
           !decoded.isEmpty
        {
            return decoded
        }
        return [:]
    }

    private static func readStringValue(
        key: String,
        managed: [String: Any],
        defaults: UserDefaults,
        environmentValue: String?
    ) -> String? {
        if let managedValue = managed[key] as? String, !managedValue.isEmpty {
            return managedValue
        }
        if let defaultsValue = defaults.string(forKey: key), !defaultsValue.isEmpty {
            return defaultsValue
        }
        if let environmentValue, !environmentValue.isEmpty {
            return environmentValue
        }
        return nil
    }

    private static func uniqueURLs(from rawValues: [String]) -> [URL] {
        var seen = Set<String>()
        return rawValues.compactMap { rawValue in
            guard let url = URL(string: rawValue), seen.insert(url.absoluteString).inserted else {
                return nil
            }
            return url
        }
    }

    private static func normalizeAddressDictionary(_ raw: [String: String]) -> [String: String] {
        raw.reduce(into: [:]) { partialResult, entry in
            let key = entry.key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = entry.value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty, !value.isEmpty else { return }
            partialResult[key] = value
        }
    }

    private static func firstNonEmpty(_ values: [String?]) -> String? {
        values
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }
}
