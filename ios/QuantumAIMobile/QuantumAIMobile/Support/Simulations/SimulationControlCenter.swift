import Foundation

@MainActor
public final class SimulationControlCenter: ObservableObject {
    public static let shared = SimulationControlCenter()

    @Published public private(set) var bundles: [SimulationVersionBundle]
    @Published public private(set) var selectedVersion: SimulationVersion
    @Published public private(set) var activatedVersions: Set<SimulationVersion>
    @Published public private(set) var syncedAt: Date?
    @Published public private(set) var activityLog: [String]

    private var hasBootstrapped = false

    public init(
        bundles: [SimulationVersionBundle] = SimulationCatalog.all,
        selectedVersion: SimulationVersion = .v3,
        activatedVersions: Set<SimulationVersion> = [.v3],
        syncedAt: Date? = nil,
        activityLog: [String] = []
    ) {
        self.bundles = bundles
        self.selectedVersion = selectedVersion
        self.activatedVersions = activatedVersions
        self.syncedAt = syncedAt
        self.activityLog = activityLog
    }

    public var selectedBundle: SimulationVersionBundle {
        bundles.first(where: { $0.version == selectedVersion }) ?? bundles[0]
    }

    public var totalVersionCount: Int { bundles.count }
    public var totalModuleCount: Int { bundles.reduce(0) { $0 + $1.modules.count } }
    public var totalPortedModuleCount: Int { bundles.reduce(0) { $0 + $1.portedModuleCount } }

    public func bootstrap() {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        syncedAt = .now
        record("Simulation stack bootstrapped with \(bundles.count) version families.")
        GlobalSinirSistemi.paylasilan.veriPompala(
            kategori: .sistem,
            mesaj: "SIMULATION STACK BOOTSTRAPPED",
            veri: [
                "versions": bundles.count,
                "modules": totalModuleCount
            ]
        )
    }

    public func applyFeatureFlags(_ flags: FeatureFlags) {
        let visible = flags.simulationVisibleVersions
        if !visible.isEmpty {
            activatedVersions = visible
            if !visible.contains(selectedVersion), let first = visible.sorted(by: { $0.rawValue < $1.rawValue }).first {
                selectedVersion = first
            }
        }
        synchronizeCatalog()
    }

    public func activate(version: SimulationVersion) {
        selectedVersion = version
        activatedVersions.insert(version)
        record("\(version.displayName) activated as compiled simulation target.")
        GlobalSinirSistemi.paylasilan.veriPompala(
            kategori: .sistem,
            mesaj: "SIMULATION TARGET ACTIVE: \(version.rawValue.uppercased())",
            veri: [
                "modules": SimulationCatalog.bundle(for: version).compiledModuleCount
            ]
        )
    }

    public func synchronizeCatalog() {
        syncedAt = .now
        record("Catalog synchronized. \(totalModuleCount) compiled surfaces ready for runtime inspection.")
        GlobalSinirSistemi.paylasilan.veriPompala(
            kategori: .sistem,
            mesaj: "SIMULATION CATALOG SYNCED",
            veri: [
                "ported": totalPortedModuleCount,
                "native": totalModuleCount - totalPortedModuleCount
            ]
        )
    }

    public func isActivated(_ version: SimulationVersion) -> Bool {
        activatedVersions.contains(version)
    }

    private func record(_ message: String) {
        let entry = "[\(Date().formatted(.dateTime.hour().minute().second()))] \(message)"
        activityLog.insert(entry, at: 0)
        if activityLog.count > 16 {
            activityLog.removeLast(activityLog.count - 16)
        }
    }
}
