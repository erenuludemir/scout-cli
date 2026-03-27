import Foundation

public struct FeatureFlags {
    public var simMode: Bool
    public var liveAdapters: Bool
    public var telemetry: Bool
    public var metricsEnabled: Bool
    public var launchTracingEnabled: Bool
    public var simulationVisibleVersions: Set<SimulationVersion>

    public static func load() -> FeatureFlags {
        guard
            let url = ResourceBundle.current.url(forResource: "FeatureFlags", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let obj = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
            let dict = obj as? [String: Any]
        else {
            return FeatureFlags(
                simMode: true,
                liveAdapters: false,
                telemetry: false,
                metricsEnabled: true,
                launchTracingEnabled: true,
                simulationVisibleVersions: [.v3, .v4, .v5]
            )
        }

        return FeatureFlags(
            simMode: dict["SimMode"] as? Bool ?? true,
            liveAdapters: dict["LiveAdapters"] as? Bool ?? false,
            telemetry: dict["Telemetry"] as? Bool ?? false,
            metricsEnabled: dict["MetricsEnabled"] as? Bool ?? true,
            launchTracingEnabled: dict["LaunchTracingEnabled"] as? Bool ?? true,
            simulationVisibleVersions: Self.readVisibleVersions(from: dict)
        )
    }

    private static func readVisibleVersions(from dict: [String: Any]) -> Set<SimulationVersion> {
        guard let raw = dict["SimulationVisibleVersions"] as? [String] else {
            return [.v3, .v4, .v5] // varsayilan: ilk uc aile aktif
        }
        let mapped = raw.compactMap { SimulationVersion(rawValue: $0) }
        return mapped.isEmpty ? [.v3, .v4, .v5] : Set(mapped)
    }
}
