import Foundation

public struct AutonomyReliabilitySnapshot: Equatable, Sendable {
    public let totalSignals: Int
    public let successfulSignals: Int
    public let failedSignals: Int
    public let recoveredFailures: Int
    public let gridCycles: Int
    public let leverageAdjustments: Int
    public let errorDistribution: [String: Int]
    public let targetEffectiveSuccessRate: Double

    public var baseSuccessRate: Double {
        guard totalSignals > 0 else { return 0 }
        return Double(successfulSignals) / Double(totalSignals)
    }

    public var recoveryRate: Double {
        guard failedSignals > 0 else { return 1 }
        return Double(recoveredFailures) / Double(failedSignals)
    }

    public var effectiveSuccessRate: Double {
        baseSuccessRate + (1 - baseSuccessRate) * recoveryRate
    }

    public var gapToTarget: Double {
        max(0, targetEffectiveSuccessRate - effectiveSuccessRate)
    }

    public static let baseline = AutonomyReliabilitySnapshot(
        totalSignals: 250,
        successfulSignals: 237,
        failedSignals: 13,
        recoveredFailures: 12,
        gridCycles: 45,
        leverageAdjustments: 8,
        errorDistribution: [
            "connection_error": 5,
            "balance_error": 3,
            "liquidation_risk": 2,
            "signal_error": 3,
        ],
        targetEffectiveSuccessRate: 0.9995
    )
}

public struct AutonomyModuleStatus: Identifiable, Equatable, Sendable {
    public let step: Int
    public let title: String
    public let stack: String
    public let detail: String
    public let route: String
    public let readiness: Double
    public let status: String

    public var id: Int { step }
}

@MainActor
public final class AutonomyControlCenter: ObservableObject {
    public static let shared = AutonomyControlCenter()

    @Published public private(set) var reliability = AutonomyReliabilitySnapshot.baseline
    @Published public private(set) var modules: [AutonomyModuleStatus] = []

    public init() {
        modules = Self.defaultModules(
            reliability: .baseline,
            liveCoverage: 0,
            twin: CognitiveTwinRegistry.shared,
            citadel: BarakfakihCitadel.shared,
            telepathy: TelepathyGateway.shared
        )
    }

    public func refresh(
        runtimeMetrics: RuntimeMetricsRegistry,
        portfolio: WalletPortfolioService
    ) {
        let twin = CognitiveTwinRegistry.shared
        let citadel = BarakfakihCitadel.shared
        let telepathy = TelepathyGateway.shared
        let base = AutonomyReliabilitySnapshot.baseline
        let liveSignals = runtimeMetrics.liveTicks
        let fallbackCount = runtimeMetrics.restFallbacks
        let recovered = min(
            base.failedSignals + fallbackCount,
            base.recoveredFailures + runtimeMetrics.wsReconnects + portfolio.recoveredNetworkCount
        )
        let successful = base.successfulSignals + max(0, liveSignals - fallbackCount)
        let failed = base.failedSignals + fallbackCount + portfolio.failedSnapshotCount
        let total = max(base.totalSignals + liveSignals + portfolio.failedSnapshotCount, successful + failed)

        var errorDistribution = base.errorDistribution
        errorDistribution["connection_error", default: 0] += runtimeMetrics.wsReconnects
        errorDistribution["balance_error", default: 0] += portfolio.failedSnapshotCount
        errorDistribution["signal_error", default: 0] += max(0, runtimeMetrics.restFallbacks - runtimeMetrics.wsReconnects)

        reliability = AutonomyReliabilitySnapshot(
            totalSignals: total,
            successfulSignals: successful,
            failedSignals: failed,
            recoveredFailures: recovered,
            gridCycles: base.gridCycles + runtimeMetrics.liveTicks,
            leverageAdjustments: base.leverageAdjustments + runtimeMetrics.restFallbacks,
            errorDistribution: errorDistribution,
            targetEffectiveSuccessRate: base.targetEffectiveSuccessRate
        )

        modules = Self.defaultModules(
            reliability: reliability,
            liveCoverage: portfolio.liveCoverage,
            twin: twin,
            citadel: citadel,
            telepathy: telepathy
        )
    }

    public func module(step: Int) -> AutonomyModuleStatus? {
        modules.first { $0.step == step }
    }

    public static func percentText(_ value: Double) -> String {
        String(format: "%.2f%%", value * 100)
    }

    private static func defaultModules(
        reliability: AutonomyReliabilitySnapshot,
        liveCoverage: Double,
        twin: CognitiveTwinRegistry,
        citadel: BarakfakihCitadel,
        telepathy: TelepathyGateway
    ) -> [AutonomyModuleStatus] {
        let eternityReadiness = min(1.0, (twin.syncProgress + citadel.integrity + liveCoverage) / 3)
        let decoderReadiness = min(1.0, (telepathy.neuralSyncPhase + liveCoverage) / 2)
        let commandReadiness = min(1.0, (telepathy.neuralSyncPhase + reliability.effectiveSuccessRate) / 2)

        return [
            AutonomyModuleStatus(
                step: 1,
                title: "Bilişsel İkiz ve Usta Protokolü",
                stack: "Python / LLM",
                detail: twin.statusText,
                route: "HQ Admin/Digital Twin",
                readiness: twin.syncProgress,
                status: twin.syncProgress >= 0.9 ? "LIVE" : "SYNCING"
            ),
            AutonomyModuleStatus(
                step: 2,
                title: "Fiziksel Köklenme - Egemen Kale",
                stack: "Swift / IoT Core",
                detail: citadel.uplinkStatus,
                route: "HQ Admin/Smart Citadel",
                readiness: citadel.integrity,
                status: citadel.isSealed ? "SEALED" : "STANDBY"
            ),
            AutonomyModuleStatus(
                step: 3,
                title: "Dashboard ETERNITY - Geleceğin Gözü",
                stack: "Composite Dashboard",
                detail: "Twin + Citadel + canlı wallet telemetrisi tek rayda",
                route: "HQ Admin/Eternity Relay",
                readiness: eternityReadiness,
                status: eternityReadiness >= 0.95 ? "HOT" : "WARM"
            ),
            AutonomyModuleStatus(
                step: 4,
                title: "Nöral Parmak İzi ve Niyet Çözücü",
                stack: "Python / BCI Decoder",
                detail: telepathy.lastIntentCode,
                route: "HQ Admin/Neural Command",
                readiness: decoderReadiness,
                status: decoderReadiness >= 0.9 ? "LOCKED" : "LEARNING"
            ),
            AutonomyModuleStatus(
                step: 5,
                title: "Düşünce-Aksiyon Yönlendiricisi",
                stack: "Swift / Neural Gateway",
                detail: String(format: "%.3f ms intent latency", telepathy.lastLatencyMs),
                route: "HQ Admin/Neural Command",
                readiness: telepathy.neuralSyncPhase,
                status: telepathy.lastLatencyMs <= 1 ? "ROUTING" : "DEGRADED"
            ),
            AutonomyModuleStatus(
                step: 6,
                title: "Dashboard Neural Command - Zihnin Aynası",
                stack: "Ops Command Surface",
                detail: "SLO \(percentText(reliability.effectiveSuccessRate)) / hedef \(percentText(reliability.targetEffectiveSuccessRate))",
                route: "HQ Admin/Neural Command",
                readiness: commandReadiness,
                status: reliability.effectiveSuccessRate >= reliability.targetEffectiveSuccessRate ? "TARGET" : "TUNING"
            ),
        ]
    }
}
