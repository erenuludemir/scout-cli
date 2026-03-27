import Foundation

@MainActor
public final class SettingsStore: ObservableObject {
    private enum Key {
        static let isPaperTrading = "qai.settings.isPaperTrading"
        static let liveAdapters = "qai.settings.liveAdapters"
        static let telemetryEnabled = "qai.settings.telemetryEnabled"
        static let marketBridgeEnabled = "qai.settings.marketBridgeEnabled"
        static let isAuthenticated = "qai.settings.isAuthenticated"
        static let licenseActivatedAt = "qai.settings.licenseActivatedAt"
        static let selectedSymbol = "qai.settings.selectedSymbol"
        static let dcaAmount = "qai.settings.dcaAmount"
        static let dcaPeriodSec = "qai.settings.dcaPeriodSec"
        static let gridLower = "qai.settings.gridLower"
        static let gridUpper = "qai.settings.gridUpper"
        static let gridSteps = "qai.settings.gridSteps"
        static let copyRatio = "qai.settings.copyRatio"
        static let shockThreshold = "qai.settings.shockThreshold"
    }

    private let defaults: UserDefaults

    @Published public var isPaperTrading: Bool {
        didSet { defaults.set(isPaperTrading, forKey: Key.isPaperTrading) }
    }

    @Published public var liveAdapters: Bool {
        didSet { defaults.set(liveAdapters, forKey: Key.liveAdapters) }
    }

    @Published public var telemetryEnabled: Bool {
        didSet { defaults.set(telemetryEnabled, forKey: Key.telemetryEnabled) }
    }

    @Published public var marketBridgeEnabled: Bool {
        didSet { defaults.set(marketBridgeEnabled, forKey: Key.marketBridgeEnabled) }
    }

    @Published public var isAuthenticated: Bool {
        didSet {
            defaults.set(isAuthenticated, forKey: Key.isAuthenticated)
            if isAuthenticated && licenseActivatedAt == nil {
                licenseActivatedAt = .now
            } else if !isAuthenticated {
                licenseActivatedAt = nil
            }
        }
    }

    @Published public var licenseActivatedAt: Date? {
        didSet { defaults.set(licenseActivatedAt, forKey: Key.licenseActivatedAt) }
    }

    @Published public var selectedSymbol: String {
        didSet { defaults.set(selectedSymbol, forKey: Key.selectedSymbol) }
    }

    @Published public var dcaAmount: Double {
        didSet { defaults.set(dcaAmount, forKey: Key.dcaAmount) }
    }

    @Published public var dcaPeriodSec: Int {
        didSet { defaults.set(dcaPeriodSec, forKey: Key.dcaPeriodSec) }
    }

    @Published public var gridLower: Double {
        didSet { defaults.set(gridLower, forKey: Key.gridLower) }
    }

    @Published public var gridUpper: Double {
        didSet { defaults.set(gridUpper, forKey: Key.gridUpper) }
    }

    @Published public var gridSteps: Int {
        didSet { defaults.set(gridSteps, forKey: Key.gridSteps) }
    }

    @Published public var copyRatio: Double {
        didSet { defaults.set(copyRatio, forKey: Key.copyRatio) }
    }

    @Published public var shockThreshold: Double {
        didSet { defaults.set(shockThreshold, forKey: Key.shockThreshold) }
    }

    public init(flags: FeatureFlags, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isPaperTrading = defaults.object(forKey: Key.isPaperTrading) as? Bool ?? flags.simMode
        self.liveAdapters = defaults.object(forKey: Key.liveAdapters) as? Bool ?? flags.liveAdapters
        self.telemetryEnabled = defaults.object(forKey: Key.telemetryEnabled) as? Bool ?? flags.telemetry
        self.marketBridgeEnabled = defaults.object(forKey: Key.marketBridgeEnabled) as? Bool ?? true
        self.isAuthenticated = defaults.object(forKey: Key.isAuthenticated) as? Bool ?? false
        self.licenseActivatedAt = defaults.object(forKey: Key.licenseActivatedAt) as? Date
        self.selectedSymbol = defaults.string(forKey: Key.selectedSymbol) ?? "BTCUSDT"
        self.dcaAmount = defaults.object(forKey: Key.dcaAmount) as? Double ?? 25
        self.dcaPeriodSec = defaults.object(forKey: Key.dcaPeriodSec) as? Int ?? 30
        self.gridLower = defaults.object(forKey: Key.gridLower) as? Double ?? 48_000
        self.gridUpper = defaults.object(forKey: Key.gridUpper) as? Double ?? 52_000
        self.gridSteps = defaults.object(forKey: Key.gridSteps) as? Int ?? 5
        self.copyRatio = defaults.object(forKey: Key.copyRatio) as? Double ?? 1.0
        self.shockThreshold = defaults.object(forKey: Key.shockThreshold) as? Double ?? 0.01
    }
}
