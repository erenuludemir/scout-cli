import Foundation
import SwiftUI

#if os(iOS)
import UIKit
#endif

enum HQAdminSegment: Int, CaseIterable, Identifiable {
    case commands
    case recovery
    case logs
    case security
    case runtime

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .commands: return "Komutlar"
        case .recovery: return "Recovery"
        case .logs: return "Logs"
        case .security: return "Security"
        case .runtime: return "Runtime"
        }
    }

    var systemImage: String {
        switch self {
        case .commands: return "command"
        case .recovery: return "cross.case.fill"
        case .logs: return "list.bullet.rectangle.portrait"
        case .security: return "shield.lefthalf.filled"
        case .runtime: return "cpu.fill"
        }
    }
}

enum HQGlobalState: String {
    case inactive
    case booting
    case active
    case degraded
    case recovering
    case critical
    case sealed

    var title: String {
        switch self {
        case .inactive: return "Inactive"
        case .booting: return "Booting"
        case .active: return "Active"
        case .degraded: return "Degraded"
        case .recovering: return "Recovering"
        case .critical: return "Critical"
        case .sealed: return "Sealed"
        }
    }

    var tint: Color {
        switch self {
        case .active: return QAITokens.Palette.teal
        case .booting, .recovering: return QAITokens.Palette.gold
        case .degraded, .inactive: return QAITokens.Palette.cardElevated
        case .critical: return QAITokens.Palette.warning
        case .sealed: return Color.red.opacity(0.82)
        }
    }

    var backgroundTint: Color {
        tint.opacity(0.22)
    }
}

enum HQModuleState: String {
    case idle
    case starting
    case running
    case warning
    case failed
    case recovering
    case stopped

    var title: String {
        switch self {
        case .idle: return "Idle"
        case .starting: return "Starting"
        case .running: return "Running"
        case .warning: return "Warning"
        case .failed: return "Failed"
        case .recovering: return "Recovering"
        case .stopped: return "Stopped"
        }
    }

    var tint: Color {
        switch self {
        case .running: return QAITokens.Palette.teal
        case .starting, .recovering: return QAITokens.Palette.gold
        case .warning: return QAITokens.Palette.warning
        case .idle, .stopped: return QAITokens.Palette.cardElevated
        case .failed: return Color.red.opacity(0.82)
        }
    }

    var backgroundTint: Color {
        tint.opacity(0.18)
    }
}

enum HQCommandState: String {
    case ready
    case executing
    case success
    case failed
    case rolledBack

    var title: String {
        switch self {
        case .ready: return "Ready"
        case .executing: return "Executing"
        case .success: return "Success"
        case .failed: return "Failed"
        case .rolledBack: return "Rolled Back"
        }
    }

    var systemImage: String {
        switch self {
        case .ready: return "bolt.horizontal.circle"
        case .executing: return "hourglass.circle"
        case .success: return "checkmark.circle.fill"
        case .failed: return "xmark.octagon.fill"
        case .rolledBack: return "arrow.uturn.backward.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .ready: return QAITokens.Palette.cardElevated
        case .executing: return QAITokens.Palette.gold
        case .success: return QAITokens.Palette.teal
        case .failed, .rolledBack: return QAITokens.Palette.warning
        }
    }

    var outcomeText: String {
        switch self {
        case .ready: return "hazır"
        case .executing: return "başlatıldı"
        case .success: return "tamamlandı"
        case .failed: return "başarısız"
        case .rolledBack: return "rollback ile tamamlandı"
        }
    }
}

enum HQGlobalAction: String, CaseIterable, Identifiable {
    case activate
    case stop
    case softRestart
    case forceRestart
    case safeMode
    case dryRun
    case emergencyStop

    var id: String { rawValue }

    var title: String {
        switch self {
        case .activate: return "Aktif Et"
        case .stop: return "Durdur"
        case .softRestart: return "Soft Restart"
        case .forceRestart: return "Force Restart"
        case .safeMode: return "Safe Mode"
        case .dryRun: return "Dry Run"
        case .emergencyStop: return "Emergency Stop"
        }
    }

    var systemImage: String {
        switch self {
        case .activate: return "play.fill"
        case .stop: return "stop.fill"
        case .softRestart: return "arrow.clockwise"
        case .forceRestart: return "bolt.trianglebadge.exclamationmark.fill"
        case .safeMode: return "shield.fill"
        case .dryRun: return "play.square.fill"
        case .emergencyStop: return "exclamationmark.octagon.fill"
        }
    }

    var isDangerous: Bool {
        self == .forceRestart || self == .emergencyStop
    }
}

enum HQModuleID: String, CaseIterable, Identifiable {
    case aiOracle
    case neuroVisor
    case healingPentest
    case quantumIntelligence
    case commandCenter
    case mainnetHQ
    case simulationStack
    case neuralCrypto
    case whaleRadar
    case vaultTransfer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .aiOracle: return "AI Oracle"
        case .neuroVisor: return "Neuro Visor"
        case .healingPentest: return "Healing & Pentest"
        case .quantumIntelligence: return "Quantum Intelligence"
        case .commandCenter: return "Command Center"
        case .mainnetHQ: return "Mainnet HQ"
        case .simulationStack: return "Simulation Stack"
        case .neuralCrypto: return "Neural Crypto"
        case .whaleRadar: return "Whale Radar"
        case .vaultTransfer: return "Vault / Transfer"
        }
    }

    var subtitle: String {
        switch self {
        case .aiOracle: return "Karar ve oracle güven katmanı"
        case .neuroVisor: return "Ajan koordinasyon ve telemetri çekirdeği"
        case .healingPentest: return "İyileştirme, scan ve pentest hattı"
        case .quantumIntelligence: return "Autonomy ve karşılaştırma zekâ yüzeyi"
        case .commandCenter: return "Dispatch, bot ve queue kontrol yüzeyi"
        case .mainnetHQ: return "Canlı ağ, adapter ve ana kanal yönetimi"
        case .simulationStack: return "Dry-run ve sim katalog yürütücüsü"
        case .neuralCrypto: return "QKD, AI optimization ve crypto güvenliği"
        case .whaleRadar: return "Whale akışı ve kopya strateji izlemesi"
        case .vaultTransfer: return "Vault senkron, transfer ve equity erişimi"
        }
    }
}

enum HQModuleCardAction: String {
    case start
    case stop
    case watch
    case log
    case fix

    var title: String {
        switch self {
        case .start: return "Başlat"
        case .stop: return "Durdur"
        case .watch: return "İzle"
        case .log: return "Log"
        case .fix: return "Düzelt"
        }
    }

    var systemImage: String {
        switch self {
        case .start: return "play.fill"
        case .stop: return "stop.fill"
        case .watch: return "eye.fill"
        case .log: return "doc.text.magnifyingglass"
        case .fix: return "wrench.and.screwdriver.fill"
        }
    }
}

enum HQRecoveryActionKind: String, CaseIterable, Identifiable {
    case selfHeal
    case fullScan
    case errorAnalysis
    case rollback
    case retryTrim
    case queueFlush
    case runtimeReset
    case telemetryExport
    case sealSystem

    var id: String { rawValue }

    var title: String {
        switch self {
        case .selfHeal: return "Self-Heal Çalıştır"
        case .fullScan: return "Full Scan Başlat"
        case .errorAnalysis: return "Hata Analizi"
        case .rollback: return "Son Stabil Sürüme Dön"
        case .retryTrim: return "Retry Oranını Düşür"
        case .queueFlush: return "Queue Flush"
        case .runtimeReset: return "Runtime Reset"
        case .telemetryExport: return "Telemetry Export"
        case .sealSystem: return "Seal System"
        }
    }

    var systemImage: String {
        switch self {
        case .selfHeal: return "cross.case.fill"
        case .fullScan: return "waveform.path.ecg.rectangle"
        case .errorAnalysis: return "stethoscope"
        case .rollback: return "arrow.uturn.backward.circle.fill"
        case .retryTrim: return "line.3.horizontal.decrease.circle.fill"
        case .queueFlush: return "tray.full.fill"
        case .runtimeReset: return "arrow.counterclockwise.circle.fill"
        case .telemetryExport: return "square.and.arrow.up.fill"
        case .sealSystem: return "lock.shield.fill"
        }
    }

    var isPrimary: Bool {
        self == .selfHeal || self == .fullScan
    }

    var isDangerous: Bool {
        self == .rollback || self == .queueFlush || self == .sealSystem
    }
}

enum HQEventLevel: Equatable {
    case info
    case warning
    case critical

    var title: String {
        switch self {
        case .info: return "INFO"
        case .warning: return "WARN"
        case .critical: return "CRIT"
        }
    }

    var tint: Color {
        switch self {
        case .info: return QAITokens.Palette.teal
        case .warning: return QAITokens.Palette.warning
        case .critical: return Color.red.opacity(0.82)
        }
    }
}

enum HQOperationTimelineFilter: String, CaseIterable, Identifiable, Equatable {
    case all
    case operatorActions
    case backend
    case device
    case runtime
    case attention

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .operatorActions: return "Operator"
        case .backend: return "Backend"
        case .device: return "Device"
        case .runtime: return "Runtime"
        case .attention: return "Attention"
        }
    }

    func matches(_ item: HQOperationTimelineItem) -> Bool {
        switch self {
        case .all:
            return true
        case .operatorActions:
            return item.source == "OPERATOR"
        case .backend:
            return item.source == "BACKEND"
        case .device:
            return item.source == "DEVICE"
        case .runtime:
            return item.source == "RUNTIME"
        case .attention:
            return item.level != .info
        }
    }
}

struct HQQuickMonitor: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let detail: String?
    let tint: Color
}

struct HQRuntimeTrendLane: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let detail: String
    let tint: Color
    let points: [Double]
}

struct HQRuntimeTrendSnapshot {
    let current: Double
    let peak: Double
    let average: Double
    let delta: Double
}

extension HQRuntimeTrendLane {
    var detailSnapshot: HQRuntimeTrendSnapshot {
        let values = points.isEmpty ? [0] : points
        let current = values.last ?? 0
        let peak = values.max() ?? current
        let average = values.reduce(0, +) / Double(values.count)
        let baseline = values.first ?? current
        return HQRuntimeTrendSnapshot(
            current: current,
            peak: peak,
            average: average,
            delta: current - baseline
        )
    }
}

struct HQRuntimeTopicItem: Identifiable {
    let id: String
    let topic: String
    let sentText: String
    let replayText: String
    let deadLetterText: String
    let lastSeenText: String
    let tint: Color
}

struct HQModuleItem: Identifiable {
    let id: HQModuleID
    let title: String
    let subtitle: String
    let state: HQModuleState
    let heartbeatText: String
    let uptimeText: String
    let lastErrorText: String
    let lastActionText: String
    let operatorText: String
    let lastSuccessText: String
    let lastFailureText: String
    let routeHint: String
}

struct HQEventItem: Identifiable {
    let id = UUID()
    let timestamp: String
    let module: String
    let level: HQEventLevel
    let message: String
    let outcome: String
}

struct HQOperationTimelineItem: Identifiable {
    let id = UUID()
    let timestamp: Date
    let timestampText: String
    let source: String
    let module: String
    let title: String
    let detail: String
    let outcome: String
    let level: HQEventLevel
}

struct HQCommandBannerModel: Identifiable {
    let id = UUID()
    let state: HQCommandState
    let title: String
    let detail: String
}

struct HQDangerRequest: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let confirmPhrase: String
    let action: HQPendingAction
}

enum HQPendingAction {
    case global(HQGlobalAction)
    case module(HQModuleID, HQModuleCardAction)
    case recovery(HQRecoveryActionKind)
}

private enum HQExecutionRole {
    case global
    case module
    case recovery
}

private struct HQModuleMemo {
    var lastAction: String = "Beklemede"
    var lastOperator: String = "system"
    var lastSuccess: Date?
    var lastFailure: Date?
}

@MainActor
final class HQAdminViewModel: ObservableObject {
    @Published var selectedSegment: HQAdminSegment = .commands
    @Published var timelineFilter: HQOperationTimelineFilter = .all
    @Published private(set) var globalState: HQGlobalState = .booting
    @Published private(set) var buildText: String = "Prod • local"
    @Published private(set) var modeText: String = "Mission Control"
    @Published private(set) var lastSyncText: String = "Sync bekleniyor"
    @Published private(set) var lastCommandText: String = "Henüz komut çalıştırılmadı"
    @Published private(set) var lastSuccessText: String = "Yok"
    @Published private(set) var lastFailureText: String = "Yok"
    @Published private(set) var commandState: HQCommandState = .ready
    @Published private(set) var quickMonitors: [HQQuickMonitor] = []
    @Published private(set) var healthTags: [String] = []
    @Published private(set) var modules: [HQModuleItem] = []
    @Published private(set) var recoveryActions: [HQRecoveryActionKind] = HQRecoveryActionKind.allCases
    @Published private(set) var events: [HQEventItem] = []
    @Published private(set) var securityMonitors: [HQQuickMonitor] = []
    @Published private(set) var securityFooter: String = ""
    @Published private(set) var runtimeMonitors: [HQQuickMonitor] = []
    @Published private(set) var runtimeFooter: String = ""
    @Published private(set) var runtimeTrendLanes: [HQRuntimeTrendLane] = []
    @Published private(set) var runtimeTopics: [HQRuntimeTopicItem] = []
    @Published private(set) var operationTimeline: [HQOperationTimelineItem] = []
    @Published var banner: HQCommandBannerModel?
    @Published var dangerRequest: HQDangerRequest?

    private let operatorID = "hq.admin"
    private let startedAt = Date()
    private var currentExecutionRole: HQExecutionRole?
    private var bannerTask: Task<Void, Never>?
    private var commandHistory: [HQEventItem] = []
    private var operatorTimeline: [HQOperationTimelineItem] = []
    private var moduleMemos: [HQModuleID: HQModuleMemo] = HQModuleID.allCases.reduce(into: [:]) {
        $0[$1] = HQModuleMemo()
    }
    private var globalLastSuccess: Date?
    private var globalLastFailure: Date?

    var timelineFilters: [HQOperationTimelineFilter] {
        HQOperationTimelineFilter.allCases.filter { filter in
            filter == .all || operationTimeline.contains(where: filter.matches)
        }
    }

    var filteredOperationTimeline: [HQOperationTimelineItem] {
        operationTimeline.filter(timelineFilter.matches)
    }

    func refresh(with env: AppEnvironment) {
        let quantum = QuantumCryptoEngine.shared
        let twin = CognitiveTwinRegistry.shared
        let citadel = BarakfakihCitadel.shared
        let telepathy = TelepathyGateway.shared
        let neuro = NeuroVisorEngine.shared
        let sinir = GlobalSinirSistemi.paylasilan
        let wealthBridge = WealthBridge.shared
        let runtimeAdmin = env.runtimeAdmin
        let queueDepth = env.health.queueDepth
        let retryRate = env.health.retryRate
        let remoteOutbox = runtimeAdmin.outbox
        let remoteQueueDepth = max(remoteOutbox.activeCount, remoteOutbox.due)
        let pentestScore = max(
            72.0,
            100.0
            - (retryRate * 100.0)
            - (Double(sinir.blockedIPCount) * 1.6)
            - (quantum.nisqNoiseLevel / 5.0)
        )

        buildText = buildLabel(env: env)
        modeText = modeLabel(env: env)
        if let lastSync = sinir.sonSenkronizasyon ?? env.walletPortfolio.lastRefreshAt {
            lastSyncText = "Son sync \(relativeText(lastSync))"
        } else {
            lastSyncText = "Sync bekleniyor"
        }
        lastSuccessText = globalLastSuccess.map(relativeText) ?? "Yok"
        lastFailureText = globalLastFailure.map(relativeText) ?? "Yok"
        globalState = deriveGlobalState(env: env)

        let ramEstimate = min(
            0.94,
            0.38
            + neuro.systemLoad * 0.42
            + Double(queueDepth) / 900.0
            + Double(env.bot.activeStrategyCount) * 0.04
        )

        quickMonitors = [
            HQQuickMonitor(
                title: "CPU",
                value: percentageText(neuro.systemLoad),
                detail: "Neuro load",
                tint: QAITokens.Palette.chipTeal
            ),
            HQQuickMonitor(
                title: "RAM",
                value: percentageText(ramEstimate),
                detail: "Runtime pressure",
                tint: QAITokens.Palette.chipBlue
            ),
            HQQuickMonitor(
                title: "Queue",
                value: "\(max(queueDepth, remoteQueueDepth))",
                detail: "L \(queueDepth) • R \(remoteQueueDepth)",
                tint: QAITokens.Palette.chipAmber
            ),
            HQQuickMonitor(
                title: "Oracle",
                value: percentageText(twin.syncProgress),
                detail: quantum.qkdStatus,
                tint: QAITokens.Palette.gold.opacity(0.8)
            )
        ]

        healthTags = [
            "Retry \(percentageText(retryRate))",
            "API \(runtimeAdmin.isReady ? "READY" : runtimeAdmin.readiness.status.uppercased())",
            "Deps \(runtimeAdmin.dependencySummary)",
            "DLQ \(remoteOutbox.deadLetter)",
            "Vault \(wealthBridge.statusText)",
            "P95 \(Int(env.health.p95LatencyMs))ms",
            "Sentinel \(sinir.blockedIPCount)"
        ]

        modules = buildModules(env: env)

        securityMonitors = [
            HQQuickMonitor(title: "Threat", value: threatLabel(quantum: quantum, blockedIPs: sinir.blockedIPCount), detail: "Threat level", tint: QAITokens.Palette.chipAmber),
            HQQuickMonitor(title: "Pentest", value: String(format: "%.1f", pentestScore), detail: "Integrity score", tint: QAITokens.Palette.chipBlue),
            HQQuickMonitor(title: "Oracle", value: quantum.qkdStatus == "ESTABLISHED" ? "Match" : "Mismatch", detail: "Oracle confidence", tint: QAITokens.Palette.chipTeal),
            HQQuickMonitor(title: "Vault", value: citadel.isSealed ? "Sealed" : "Open", detail: wealthBridge.statusText, tint: QAITokens.Palette.cardElevated),
            HQQuickMonitor(title: "Gateway", value: runtimeAdmin.isReady ? "Ready" : runtimeAdmin.readiness.status.capitalized, detail: runtimeAdmin.dependencySummary, tint: runtimeAdmin.isReady ? QAITokens.Palette.chipTeal : QAITokens.Palette.chipAmber),
            HQQuickMonitor(title: "Sentinel", value: "\(sinir.blockedIPCount)", detail: "Suspicious events", tint: QAITokens.Palette.chipAmber)
        ]

        securityFooter = [
            "Oracle \(quantum.qkdStatus)",
            "Twin \(percentageText(twin.syncProgress))",
            "Intent \(telepathy.lastIntentCode)",
            "Citadel \(citadel.uplinkStatus)"
        ].joined(separator: " • ")

        runtimeMonitors = [
            HQQuickMonitor(title: "API", value: runtimeAdmin.isReady ? "READY" : runtimeAdmin.readiness.status.uppercased(), detail: runtimeAdmin.readiness.service, tint: runtimeAdmin.isReady ? QAITokens.Palette.chipTeal : QAITokens.Palette.chipAmber),
            HQQuickMonitor(title: "Deps", value: runtimeAdmin.dependencySummary, detail: "Connected", tint: runtimeAdmin.isReady ? QAITokens.Palette.chipBlue : QAITokens.Palette.chipAmber),
            HQQuickMonitor(title: "Due", value: "\(remoteOutbox.due)", detail: "Retryable outbox", tint: remoteOutbox.due > 0 ? QAITokens.Palette.chipAmber : QAITokens.Palette.chipTeal),
            HQQuickMonitor(title: "DLQ", value: "\(remoteOutbox.deadLetter)", detail: "Dead letters", tint: remoteOutbox.deadLetter > 0 ? QAITokens.Palette.warning.opacity(0.24) : QAITokens.Palette.cardElevated),
            HQQuickMonitor(title: "Workers", value: "\(activeWorkerCount(env: env))", detail: "Active workers", tint: QAITokens.Palette.chipBlue),
            HQQuickMonitor(title: "Retry", value: percentageText(retryRate), detail: "Retry ratio", tint: QAITokens.Palette.chipTeal),
            HQQuickMonitor(title: "Live Ticks", value: "\(env.runtimeMetrics.liveTicks)", detail: "Market ticks", tint: QAITokens.Palette.chipBlue),
            HQQuickMonitor(title: "Fallbacks", value: "\(env.runtimeMetrics.restFallbacks)", detail: "REST fallback", tint: QAITokens.Palette.chipAmber)
        ]

        runtimeFooter = [
            "API \(runtimeAdmin.isReady ? "ready" : runtimeAdmin.readiness.status)",
            "Outbox due \(remoteOutbox.due) • dlq \(remoteOutbox.deadLetter)",
            "Action \(runtimeAdmin.lastAction)",
            "Update \(runtimeAdmin.lastUpdatedAt.map(relativeText) ?? "bekleniyor")",
            "Session uptime: \(uptimeText(from: startedAt))"
        ].joined(separator: " • ")

        runtimeTrendLanes = buildRuntimeTrendLanes(runtimeAdmin: runtimeAdmin)
        runtimeTopics = buildRuntimeTopics(runtimeAdmin: runtimeAdmin)
        operationTimeline = buildOperationTimeline(env: env)
        if !timelineFilters.contains(timelineFilter) {
            timelineFilter = .all
        }
        events = buildEvents(env: env)
    }

    func runGlobalAction(_ action: HQGlobalAction, env: AppEnvironment) {
        if action.isDangerous {
            dangerRequest = makeDangerRequest(for: .global(action))
            return
        }

        execute(
            title: action.title,
            module: "Global",
            role: .global
        ) { [weak self] in
            guard let self else { return .failed }
            return await self.performGlobalAction(action, env: env)
        }
    }

    func runModuleAction(_ action: HQModuleCardAction, module: HQModuleID, env: AppEnvironment) {
        if action == .stop && module == .mainnetHQ {
            dangerRequest = makeDangerRequest(for: .module(module, action))
            return
        }

        execute(
            title: action.title,
            module: module.title,
            role: .module
        ) { [weak self] in
            guard let self else { return .failed }
            return await self.performModuleAction(action, module: module, env: env)
        }
    }

    func runRecoveryAction(_ action: HQRecoveryActionKind, env: AppEnvironment) {
        if action.isDangerous {
            dangerRequest = makeDangerRequest(for: .recovery(action))
            return
        }

        execute(
            title: action.title,
            module: "Recovery",
            role: .recovery
        ) { [weak self] in
            guard let self else { return .failed }
            return await self.performRecoveryAction(action, env: env)
        }
    }

    func cancelDangerAction() {
        dangerRequest = nil
    }

    func confirmDangerAction(env: AppEnvironment) {
        guard let request = dangerRequest else { return }
        dangerRequest = nil

        switch request.action {
        case .global(let action):
            execute(title: action.title, module: "Global", role: .global) { [weak self] in
                guard let self else { return .failed }
                return await self.performGlobalAction(action, env: env)
            }

        case .module(let module, let action):
            execute(title: action.title, module: module.title, role: .module) { [weak self] in
                guard let self else { return .failed }
                return await self.performModuleAction(action, module: module, env: env)
            }

        case .recovery(let action):
            execute(title: action.title, module: "Recovery", role: .recovery) { [weak self] in
                guard let self else { return .failed }
                return await self.performRecoveryAction(action, env: env)
            }
        }
    }

    private func execute(
        title: String,
        module: String,
        role: HQExecutionRole,
        operation: @escaping @MainActor () async -> HQCommandState
    ) {
        currentExecutionRole = role
        commandState = .executing
        lastCommandText = "\(module) • \(title)"
        showBanner(
            state: .executing,
            title: title,
            detail: "\(module) komutu başlatıldı"
        )
        recordTimelineItem(
            source: "OPERATOR",
            module: module,
            title: title,
            detail: "\(module) komutu başlatıldı",
            outcome: HQCommandState.executing.title,
            level: .info
        )
        emitHaptic(for: .executing)

        Task { @MainActor [weak self] in
            guard let self else { return }
            let result = await operation()
            self.commandState = result
            self.currentExecutionRole = nil
            self.showBanner(
                state: result,
                title: title,
                detail: "\(module) komutu \(result.outcomeText)"
            )
            self.recordTimelineItem(
                source: "OPERATOR",
                module: module,
                title: title,
                detail: "\(module) komutu \(result.outcomeText)",
                outcome: result.title,
                level: self.timelineLevel(for: result)
            )
            self.recordEvent(
                module: module,
                level: result == .failed ? .critical : .info,
                message: title,
                outcome: result.title
            )
            self.emitHaptic(for: result)
            self.refreshSuccessFailureTimestamps(for: result)
        }
    }

    private func performGlobalAction(_ action: HQGlobalAction, env: AppEnvironment) async -> HQCommandState {
        switch action {
        case .activate:
            env.settings.liveAdapters = true
            env.settings.isPaperTrading = false
            env.settings.telemetryEnabled = true
            env.settings.marketBridgeEnabled = true
            env.applyRuntimeSettings()
            await env.walletPortfolio.refreshNow()

        case .stop:
            env.bot.stopAll()
            env.copyTrade.stop()
            env.settings.liveAdapters = false
            env.settings.isPaperTrading = true
            env.applyRuntimeSettings()

        case .softRestart:
            env.applyRuntimeSettings()
            await env.walletPortfolio.refreshNow()

        case .forceRestart:
            env.bot.stopAll()
            env.copyTrade.stop()
            env.market.stopAll(clearLastTick: false)
            env.applyRuntimeSettings()
            await env.walletPortfolio.refreshNow()

        case .safeMode:
            env.bot.stopAll()
            env.copyTrade.stop()
            env.settings.isPaperTrading = true
            env.settings.liveAdapters = false
            env.settings.marketBridgeEnabled = false
            env.applyRuntimeSettings()

        case .dryRun:
            env.settings.isPaperTrading = true
            env.applyRuntimeSettings()

        case .emergencyStop:
            env.bot.stopAll()
            env.copyTrade.stop()
            env.market.stopAll(clearLastTick: false)
            env.settings.liveAdapters = false
            env.settings.marketBridgeEnabled = false
            BarakfakihCitadel.shared.fortifyPhysicalAnchor()
        }

        env.audit.append(
            action: "hq.global.\(action.rawValue)",
            payload: ["operator": operatorID]
        )
        GlobalSinirSistemi.paylasilan.veriPompala(
            kategori: action.isDangerous ? .alarm : .sistem,
            mesaj: "HQ GLOBAL ACTION: \(action.title.uppercased())",
            veri: ["operator": operatorID]
        )
        _ = await env.runtimeAdmin.refresh()
        refresh(with: env)
        return .success
    }

    private func performModuleAction(
        _ action: HQModuleCardAction,
        module: HQModuleID,
        env: AppEnvironment
    ) async -> HQCommandState {
        var memo = moduleMemos[module] ?? HQModuleMemo()
        memo.lastAction = action.title
        memo.lastOperator = operatorID

        switch action {
        case .watch:
            selectedSegment = .logs

        case .log:
            selectedSegment = .logs

        case .fix:
            selectedSegment = module == .healingPentest ? .recovery : .logs

        case .start:
            switch module {
            case .aiOracle:
                env.training.loadIfNeeded(priority: .userInitiated)
                CognitiveTwinRegistry.shared.mentorHeir(currentHeirAgeMonths: 54)

            case .neuroVisor:
                TelepathyGateway.shared.processBrainwaveCommand(intentCode: "INTENT_MONITOR")

            case .healingPentest:
                await env.walletPortfolio.refreshNow()
                env.applyRuntimeSettings()

            case .quantumIntelligence:
                AutonomyControlCenter.shared.refresh(
                    runtimeMetrics: env.runtimeMetrics,
                    portfolio: env.walletPortfolio
                )

            case .commandCenter:
                env.bot.startDCA(amount: env.settings.dcaAmount, periodSec: env.settings.dcaPeriodSec)

            case .mainnetHQ:
                env.settings.liveAdapters = true
                env.settings.isPaperTrading = false
                env.applyRuntimeSettings()

            case .simulationStack:
                env.settings.isPaperTrading = true
                env.applyRuntimeSettings()
                env.simulations.synchronizeCatalog()

            case .neuralCrypto:
                if !QuantumCryptoEngine.shared.isAIOptimized {
                    QuantumCryptoEngine.shared.toggleAIOptimization()
                }

            case .whaleRadar:
                WhaleWatcher.shared.startSniffing()
                env.copyTrade.start(source: env.settings.selectedSymbol, ratio: env.settings.copyRatio)

            case .vaultTransfer:
                let pnl = env.bot.estimatedPnL(currentPrice: env.market.last?.price)
                WealthBridge.shared.evaluateWithdrawal(currentProfit: pnl)
                await env.walletPortfolio.refreshNow()
            }

        case .stop:
            switch module {
            case .commandCenter:
                env.bot.stopAll()
                env.copyTrade.stop()

            case .mainnetHQ:
                env.bot.stopAll()
                env.copyTrade.stop()
                env.settings.liveAdapters = false
                env.settings.isPaperTrading = true
                env.applyRuntimeSettings()

            case .simulationStack:
                env.settings.isPaperTrading = false
                env.applyRuntimeSettings()

            case .neuralCrypto:
                if QuantumCryptoEngine.shared.isAIOptimized {
                    QuantumCryptoEngine.shared.toggleAIOptimization()
                }

            case .whaleRadar:
                env.copyTrade.stop()

            case .vaultTransfer:
                env.settings.marketBridgeEnabled = false
                env.applyRuntimeSettings()

            default:
                break
            }
        }

        if action == .fix {
            switch module {
            case .healingPentest:
                await env.sync.flushOutbox()
                await env.walletPortfolio.refreshNow()
                env.applyRuntimeSettings()

            case .mainnetHQ:
                env.applyRuntimeSettings()

            case .vaultTransfer:
                await env.walletPortfolio.refreshNow()

            case .neuroVisor:
                TelepathyGateway.shared.processBrainwaveCommand(intentCode: "INTENT_QKD_MONITOR")

            default:
                break
            }
        }

        env.audit.append(
            action: "hq.module.\(module.rawValue).\(action.rawValue)",
            payload: ["operator": operatorID]
        )
        GlobalSinirSistemi.paylasilan.veriPompala(
            kategori: .sistem,
            mesaj: "HQ MODULE ACTION: \(module.title.uppercased()) \(action.title.uppercased())",
            veri: ["operator": operatorID]
        )

        memo.lastSuccess = .now
        moduleMemos[module] = memo
        _ = await env.runtimeAdmin.refresh()
        refresh(with: env)
        return .success
    }

    private func performRecoveryAction(
        _ action: HQRecoveryActionKind,
        env: AppEnvironment
    ) async -> HQCommandState {
        var remoteActionSucceeded = true

        switch action {
        case .selfHeal:
            env.applyRuntimeSettings()
            await env.sync.flushOutbox()
            await env.walletPortfolio.refreshNow()
            remoteActionSucceeded = await env.runtimeAdmin.refresh()

        case .fullScan:
            env.training.loadIfNeeded(priority: .userInitiated)
            _ = QuantumSecurityProvider.shared.initiateQKDExchange()
            await env.walletPortfolio.refreshNow()
            remoteActionSucceeded = await env.runtimeAdmin.refresh()

        case .errorAnalysis:
            selectedSegment = .logs

        case .rollback:
            env.bot.stopAll()
            env.copyTrade.stop()
            env.settings.liveAdapters = false
            env.settings.isPaperTrading = true
            env.settings.marketBridgeEnabled = false
            env.applyRuntimeSettings()
            recordRecoveryTelemetry(action)
            refresh(with: env)
            return .rolledBack

        case .retryTrim:
            await env.sync.flushOutbox()
            let replayed = await env.runtimeAdmin.replayDeadLetters()
            let drained = await env.runtimeAdmin.drainOutbox()
            remoteActionSucceeded = replayed != nil && drained != nil

        case .queueFlush:
            env.storage.clearOutbox()
            if env.runtimeAdmin.hasSnapshot {
                _ = await env.runtimeAdmin.drainOutbox()
            }

        case .runtimeReset:
            env.bot.stopAll()
            env.market.stopAll(clearLastTick: false)
            env.applyRuntimeSettings()
            remoteActionSucceeded = await env.runtimeAdmin.refresh()

        case .telemetryExport:
            if let url = env.storage.exportOrdersCSV() {
                showBanner(
                    state: .success,
                    title: action.title,
                    detail: "CSV hazır: \(url.lastPathComponent)"
                )
            }

        case .sealSystem:
            env.bot.stopAll()
            env.copyTrade.stop()
            BarakfakihCitadel.shared.fortifyPhysicalAnchor()
        }

        recordRecoveryTelemetry(action)
        refresh(with: env)
        return remoteActionSucceeded ? .success : .failed
    }

    private func recordRecoveryTelemetry(_ action: HQRecoveryActionKind) {
        GlobalSinirSistemi.paylasilan.veriPompala(
            kategori: action.isDangerous ? .alarm : .sistem,
            mesaj: "HQ RECOVERY ACTION: \(action.title.uppercased())",
            veri: ["operator": operatorID]
        )
    }

    private func deriveGlobalState(env: AppEnvironment) -> HQGlobalState {
        let quantum = QuantumCryptoEngine.shared
        let citadel = BarakfakihCitadel.shared
        let retryRate = env.health.retryRate
        let runtimeAdmin = env.runtimeAdmin

        if citadel.isSealed { return .sealed }
        if commandState == .executing && currentExecutionRole == .recovery { return .recovering }
        if env.walletPortfolio.lastRefreshAt == nil && env.market.last == nil { return .booting }
        if runtimeAdmin.hasSnapshot {
            if runtimeAdmin.outbox.deadLetter > 0 { return .critical }
            if !env.runtimeUsesSimulation && !runtimeAdmin.isReady { return .critical }
            if runtimeAdmin.outbox.due > 0 || runtimeAdmin.outbox.failed > 0 {
                return .degraded
            }
        }
        if quantum.qkdStatus == "COMPROMISED" { return .critical }
        if !env.runtimeUsesSimulation && env.market.lastError != nil { return .critical }
        if retryRate > 0.24 { return .critical }
        if env.health.queueDepth > 0 || retryRate > 0.08 || env.walletPortfolio.lastError != nil {
            return .degraded
        }
        if !env.settings.liveAdapters && !env.settings.isPaperTrading && env.bot.activeStrategyCount == 0 {
            return .inactive
        }
        return .active
    }

    private func buildModules(env: AppEnvironment) -> [HQModuleItem] {
        let quantum = QuantumCryptoEngine.shared
        let twin = CognitiveTwinRegistry.shared
        let autonomy = AutonomyControlCenter.shared
        let neuro = NeuroVisorEngine.shared
        let sinir = GlobalSinirSistemi.paylasilan
        let wealthBridge = WealthBridge.shared
        let runtimeAdmin = env.runtimeAdmin

        return HQModuleID.allCases.map { moduleID in
            let memo = moduleMemos[moduleID] ?? HQModuleMemo()
            let state: HQModuleState
            let heartbeat: String
            let uptime: String
            let lastError: String
            let routeHint: String

            switch moduleID {
            case .aiOracle:
                state = quantum.qkdStatus == "COMPROMISED" ? .failed : (quantum.isSyncing || env.training.isLoading ? .starting : (twin.syncProgress >= 0.7 ? .running : .warning))
                heartbeat = relativeClockText(from: sinir.sonSenkronizasyon, fallback: "2 sn")
                uptime = uptimeText(from: startedAt)
                lastError = quantum.qkdStatus == "COMPROMISED" ? "Oracle mismatch algılandı" : "Yok"
                routeHint = "Twin sync \(percentageText(twin.syncProgress))"

            case .neuroVisor:
                state = neuro.systemLoad > 0.58 ? .warning : .running
                heartbeat = "2 sn"
                uptime = uptimeText(from: startedAt)
                lastError = neuro.systemLoad > 0.58 ? "Telemetry load spike" : "Yok"
                routeHint = "Latency \(String(format: "%.3f", TelepathyGateway.shared.lastLatencyMs)) ms"

            case .healingPentest:
                state = runtimeAdmin.outbox.deadLetter > 0
                ? .failed
                : (env.health.retryRate > 0.25
                   ? .failed
                   : (env.health.retryRate > 0.08 || sinir.blockedIPCount > 0 || runtimeAdmin.outbox.failed > 0 || runtimeAdmin.outbox.due > 0 ? .warning : .running))
                heartbeat = relativeClockText(from: env.walletPortfolio.lastRefreshAt, fallback: "5 sn")
                uptime = uptimeText(from: startedAt)
                lastError = runtimeAdmin.outbox.deadLetter > 0
                ? "Dead-letter queue \(runtimeAdmin.outbox.deadLetter)"
                : (env.health.retryRate > 0.08 ? "Retry threshold yükseldi" : "Yok")
                routeHint = "P95 \(Int(env.health.p95LatencyMs))ms • due \(runtimeAdmin.outbox.due)"

            case .quantumIntelligence:
                state = autonomy.reliability.gapToTarget > 0.02 ? .warning : .running
                heartbeat = relativeClockText(from: env.walletPortfolio.lastRefreshAt, fallback: "3 sn")
                uptime = uptimeText(from: startedAt)
                lastError = autonomy.reliability.gapToTarget > 0.02 ? "Target gap sürüyor" : "Yok"
                routeHint = "Effective \(AutonomyControlCenter.percentText(autonomy.reliability.effectiveSuccessRate))"

            case .commandCenter:
                state = env.bot.activeStrategyCount == 0 && !env.copyTrade.isActive
                ? .idle
                : (env.health.queueDepth > 0 || runtimeAdmin.outbox.due > 0 || runtimeAdmin.outbox.deadLetter > 0 ? .warning : .running)
                heartbeat = relativeClockText(from: sinir.sonSenkronizasyon, fallback: "1 sn")
                uptime = uptimeText(from: startedAt)
                lastError = runtimeAdmin.outbox.deadLetter > 0
                ? "Dead-letter queue mevcut"
                : (env.health.queueDepth > 0 ? "Queue backlog mevcut" : "Yok")
                routeHint = "\(env.bot.activeStrategyCount) strategy • due \(runtimeAdmin.outbox.due)"

            case .mainnetHQ:
                state = env.runtimeUsesSimulation
                ? .stopped
                : (runtimeAdmin.hasSnapshot && !runtimeAdmin.isReady
                   ? .warning
                   : (env.market.lastError != nil ? .warning : (env.market.last == nil ? .starting : .running)))
                heartbeat = env.runtimeUsesSimulation ? "sim" : relativeClockText(from: env.walletPortfolio.lastRefreshAt, fallback: "1 sn")
                uptime = uptimeText(from: startedAt)
                lastError = (!env.runtimeUsesSimulation && runtimeAdmin.hasSnapshot && !runtimeAdmin.isReady)
                ? "Backend dependency degraded"
                : (env.market.lastError ?? "Yok")
                routeHint = "\(env.market.sourceText) • \(runtimeAdmin.hasSnapshot ? runtimeAdmin.dependencySummary : "API sync")"

            case .simulationStack:
                state = env.runtimeUsesSimulation ? .running : (env.simulations.syncedAt == nil ? .starting : .idle)
                heartbeat = relativeClockText(from: env.simulations.syncedAt, fallback: "Bekleniyor")
                uptime = uptimeText(from: env.simulations.syncedAt ?? startedAt)
                lastError = env.simulations.syncedAt == nil ? "Catalog sync bekleniyor" : "Yok"
                routeHint = "\(env.simulations.totalModuleCount) module"

            case .neuralCrypto:
                state = quantum.isSyncing ? .starting : (quantum.qkdStatus == "COMPROMISED" ? .failed : (quantum.isAIOptimized ? .running : .warning))
                heartbeat = relativeClockText(from: sinir.sonSenkronizasyon, fallback: "2 sn")
                uptime = uptimeText(from: startedAt)
                lastError = quantum.qkdStatus == "COMPROMISED" ? "QKD compromised" : "Yok"
                routeHint = quantum.multiplierText

            case .whaleRadar:
                state = env.copyTrade.isActive ? .running : (env.settings.telemetryEnabled ? .idle : .stopped)
                heartbeat = env.copyTrade.isActive ? "2 sn" : "—"
                uptime = uptimeText(from: startedAt)
                lastError = env.copyTrade.isActive ? "Yok" : "Live follow bekleniyor"
                routeHint = env.settings.selectedSymbol

            case .vaultTransfer:
                state = env.walletPortfolio.lastError != nil ? .warning : (wealthBridge.statusText == "TETIKLENDI" || env.walletPortfolio.selectedSnapshot?.isLive == true ? .running : .idle)
                heartbeat = relativeClockText(from: env.walletPortfolio.lastRefreshAt, fallback: "Bekleniyor")
                uptime = uptimeText(from: env.walletPortfolio.lastRefreshAt ?? startedAt)
                lastError = env.walletPortfolio.lastError ?? "Yok"
                routeHint = wealthBridge.statusText
            }

            return HQModuleItem(
                id: moduleID,
                title: moduleID.title,
                subtitle: moduleID.subtitle,
                state: state,
                heartbeatText: heartbeat,
                uptimeText: uptime,
                lastErrorText: lastError,
                lastActionText: memo.lastAction,
                operatorText: memo.lastOperator,
                lastSuccessText: memo.lastSuccess.map(relativeText) ?? "Yok",
                lastFailureText: memo.lastFailure.map(relativeText) ?? "Yok",
                routeHint: routeHint
            )
        }
    }

    private func buildEvents(env: AppEnvironment) -> [HQEventItem] {
        let backendAuditEvents = env.runtimeAdmin.recentAudits.prefix(5).map { item in
            HQEventItem(
                timestamp: shortClockText(from: item.createdAtText),
                module: displayModuleTitle(forTopic: item.topic),
                level: eventLevel(forAudit: item),
                message: item.detail ?? "\(item.action.uppercased()) \(item.topic)",
                outcome: "\(item.action.uppercased()) • \(item.status.uppercased())"
            )
        }
        let runtimeEvents = env.runtimeAdmin.deadLetterEvents.prefix(3).map { item in
            HQEventItem(
                timestamp: shortClockText(from: item.createdAtText),
                module: "OUTBOX",
                level: .critical,
                message: item.lastError ?? item.aggregateID,
                outcome: "DLQ #\(item.attempts)"
            )
        } + env.runtimeAdmin.retryableEvents.prefix(2).map { item in
            HQEventItem(
                timestamp: shortClockText(from: item.createdAtText),
                module: "OUTBOX",
                level: .warning,
                message: item.lastError ?? item.aggregateID,
                outcome: item.status.uppercased()
            )
        }
        let telemetryEvents = GlobalSinirSistemi.paylasilan.telemetryLog.prefix(6).map(parseTelemetryEntry)
        let auditEvents = env.storage.audits.suffix(4).reversed().map { audit in
            HQEventItem(
                timestamp: Self.clockFormatter.string(from: audit.ts),
                module: audit.action.components(separatedBy: ".").first?.uppercased() ?? "AUDIT",
                level: audit.action.contains("panic") || audit.action.contains("exhausted") ? .critical : .info,
                message: audit.action,
                outcome: audit.actor
            )
        }

        return Array((commandHistory + backendAuditEvents + runtimeEvents + telemetryEvents + auditEvents).prefix(14))
    }

    private func buildOperationTimeline(env: AppEnvironment) -> [HQOperationTimelineItem] {
        let backendAuditTimeline = env.runtimeAdmin.recentAudits.prefix(6).map { item in
            HQOperationTimelineItem(
                timestamp: timestampDate(from: item.createdAtText) ?? .distantPast,
                timestampText: shortClockText(from: item.createdAtText),
                source: "BACKEND",
                module: displayModuleTitle(forTopic: item.topic),
                title: item.action.uppercased(),
                detail: item.detail ?? item.topic,
                outcome: item.status.uppercased(),
                level: eventLevel(forAudit: item)
            )
        }
        let deviceAuditTimeline = env.storage.audits
            .suffix(4)
            .reversed()
            .map { audit in
                HQOperationTimelineItem(
                    timestamp: audit.ts,
                    timestampText: Self.clockFormatter.string(from: audit.ts),
                    source: "DEVICE",
                    module: auditModule(for: audit.action),
                    title: auditTitle(for: audit.action),
                    detail: audit.action,
                    outcome: audit.actor.uppercased(),
                    level: auditLevel(for: audit.action)
                )
            }
        let runtimeSyncTimeline = env.runtimeAdmin.lastUpdatedAt.map { lastUpdatedAt in
            HQOperationTimelineItem(
                timestamp: lastUpdatedAt,
                timestampText: Self.clockFormatter.string(from: lastUpdatedAt),
                source: "RUNTIME",
                module: "API",
                title: "SYNC",
                detail: env.runtimeAdmin.lastAction,
                outcome: env.runtimeAdmin.isReady ? "READY" : env.runtimeAdmin.readiness.status.uppercased(),
                level: env.runtimeAdmin.isReady ? .info : .warning
            )
        }

        let combined = operatorTimeline + backendAuditTimeline + deviceAuditTimeline + (runtimeSyncTimeline.map { [$0] } ?? [])
        return Array(combined.sorted { $0.timestamp > $1.timestamp }.prefix(10))
    }

    private func parseTelemetryEntry(_ entry: String) -> HQEventItem {
        let firstClosing = entry.firstIndex(of: "]")
        let time = firstClosing.map { String(entry[entry.index(after: entry.startIndex)..<$0]) } ?? Self.clockFormatter.string(from: .now)

        var remainder = firstClosing.map { String(entry[entry.index(after: $0)...]).trimmingCharacters(in: .whitespaces) } ?? entry
        let secondOpening = remainder.firstIndex(of: "[")
        let secondClosing = remainder.firstIndex(of: "]")
        let category = if let secondOpening, let secondClosing {
            String(remainder[remainder.index(after: secondOpening)..<secondClosing])
        } else {
            "SYSTEM"
        }

        if let secondClosing {
            remainder = String(remainder[remainder.index(after: secondClosing)...]).trimmingCharacters(in: .whitespaces)
        }

        let uppercased = remainder.uppercased()
        let level: HQEventLevel
        if category == OlayKategorisi.alarm.rawValue || uppercased.contains("TIMEOUT") || uppercased.contains("COMPROMISED") {
            level = .critical
        } else if uppercased.contains("RETRY") || uppercased.contains("LOCK") {
            level = .warning
        } else {
            level = .info
        }

        return HQEventItem(
            timestamp: time,
            module: displayModuleTitle(for: category),
            level: level,
            message: remainder,
            outcome: "Bus"
        )
    }

    private func displayModuleTitle(for category: String) -> String {
        switch category {
        case OlayKategorisi.kar.rawValue: return "VAULT"
        case OlayKategorisi.alarm.rawValue: return "SECURITY"
        case OlayKategorisi.pazarlama.rawValue: return "WHALE"
        case OlayKategorisi.emir.rawValue: return "RUNTIME"
        default: return "SYSTEM"
        }
    }

    private func displayModuleTitle(forTopic topic: String) -> String {
        if topic.contains("dead_letter") { return "DLQ" }
        if topic.contains("replay") { return "REPLAY" }
        if topic.contains("orders") { return "OUTBOX" }
        return "RUNTIME"
    }

    private func eventLevel(forAudit item: RuntimeAdminAuditEntry) -> HQEventLevel {
        if item.action == "dead_letter" || item.status.contains("failed") {
            return .critical
        }
        if item.action == "replay" || item.status != "sent" {
            return .warning
        }
        return .info
    }

    private func buildRuntimeTrendLanes(runtimeAdmin: RuntimeAdminMonitor) -> [HQRuntimeTrendLane] {
        let trend = runtimeAdmin.runbook.trendPoints
        guard !trend.isEmpty else { return [] }
        return [
            HQRuntimeTrendLane(
                title: "Queue Pressure",
                value: "\(trend.last!.outboxDue + trend.last!.outboxFailed + trend.last!.outboxDeadLetter)",
                detail: "due + failed + dlq",
                tint: QAITokens.Palette.chipAmber,
                points: trend.map { Double($0.outboxDue + $0.outboxFailed + $0.outboxDeadLetter) }
            ),
            HQRuntimeTrendLane(
                title: "Relay Sent",
                value: "\(trend.last!.relaySent)",
                detail: "published orders",
                tint: QAITokens.Palette.chipTeal,
                points: trend.map { Double($0.relaySent) }
            ),
            HQRuntimeTrendLane(
                title: "Replay",
                value: "\(trend.last!.relayReplay)",
                detail: "manual recovery",
                tint: QAITokens.Palette.gold.opacity(0.8),
                points: trend.map { Double($0.relayReplay) }
            ),
            HQRuntimeTrendLane(
                title: "Dependencies",
                value: "\(trend.last!.connectedDependencies)/\(max(trend.last!.totalDependencies, 1))",
                detail: "connected checks",
                tint: QAITokens.Palette.chipBlue,
                points: trend.map { Double($0.connectedDependencies) }
            )
        ]
    }

    private func buildRuntimeTopics(runtimeAdmin: RuntimeAdminMonitor) -> [HQRuntimeTopicItem] {
        runtimeAdmin.runbook.topicActivity.prefix(4).map { item in
            let tint: Color = item.deadLetterCount > 0
                ? QAITokens.Palette.warning.opacity(0.24)
                : (item.replayCount > 0 ? QAITokens.Palette.chipAmber : QAITokens.Palette.cardElevated)
            return HQRuntimeTopicItem(
                id: item.topic,
                topic: item.topic,
                sentText: "\(item.sentCount)",
                replayText: "\(item.replayCount)",
                deadLetterText: "\(item.deadLetterCount)",
                lastSeenText: shortClockText(from: item.lastSeenAtText),
                tint: tint
            )
        }
    }

    private func auditModule(for action: String) -> String {
        if action.contains("hq.global") { return "GLOBAL" }
        if action.contains("hq.module") { return "MODULE" }
        if action.contains("hq.recovery") { return "RECOVERY" }
        return "AUDIT"
    }

    private func auditTitle(for action: String) -> String {
        action
            .split(separator: ".")
            .suffix(2)
            .joined(separator: " ")
            .replacingOccurrences(of: "_", with: " ")
            .uppercased()
    }

    private func auditLevel(for action: String) -> HQEventLevel {
        if action.contains("panic") || action.contains("seal") || action.contains("emergency") {
            return .critical
        }
        if action.contains("rollback") || action.contains("retry") || action.contains("flush") {
            return .warning
        }
        return .info
    }

    private func buildLabel(env: AppEnvironment) -> String {
        let bundle = Bundle.main
        let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "local"
        let build = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "dev"
        let tier = env.runtimeUsesSimulation ? "Simulation" : "Production"
        return "\(tier) • v\(version) (\(build))"
    }

    private func modeLabel(env: AppEnvironment) -> String {
        let safeMode = env.settings.isPaperTrading && !env.settings.liveAdapters
        return [
            "Mission Control",
            "Dry Run \(env.settings.isPaperTrading ? "On" : "Off")",
            "Safe Mode \(safeMode ? "On" : "Off")",
            "Telemetry \(env.settings.telemetryEnabled ? "On" : "Off")"
        ].joined(separator: " • ")
    }

    private func makeDangerRequest(for pending: HQPendingAction) -> HQDangerRequest {
        switch pending {
        case .global(.forceRestart):
            return HQDangerRequest(
                title: "Force Restart",
                message: "Çalışan runtime resetlenecek, aktif queue yeniden bağlanacak ve modüller zorla tekrar başlatılacak.",
                confirmPhrase: "FORCE",
                action: pending
            )

        case .global(.emergencyStop):
            return HQDangerRequest(
                title: "Emergency Stop",
                message: "Tüm kritik akışlar durdurulacak, market hattı kesilecek ve sistem koruma moduna alınacak.",
                confirmPhrase: "STOP",
                action: pending
            )

        case .module(.mainnetHQ, _):
            return HQDangerRequest(
                title: "Mainnet HQ Stop",
                message: "Canlı adapter hattı kesilecek ve ekran güvenli sim moduna düşecek.",
                confirmPhrase: "MAINNET",
                action: pending
            )

        case .recovery(.rollback):
            return HQDangerRequest(
                title: "Rollback",
                message: "Sistem son stabil profile dönecek ve mevcut canlı akışlar güvenli moda alınacak.",
                confirmPhrase: "ROLLBACK",
                action: pending
            )

        case .recovery(.queueFlush):
            return HQDangerRequest(
                title: "Queue Flush",
                message: "Bekleyen tüm queue kalemleri temizlenecek. Bu işlem geri alınamaz.",
                confirmPhrase: "FLUSH",
                action: pending
            )

        case .recovery(.sealSystem):
            return HQDangerRequest(
                title: "Seal System",
                message: "Citadel mühürlenecek ve kritik yüzeyler kilitli moda geçecek.",
                confirmPhrase: "SEAL",
                action: pending
            )

        default:
            return HQDangerRequest(
                title: "Protected Action",
                message: "Bu komut iki aşamalı onay gerektirir.",
                confirmPhrase: "CONFIRM",
                action: pending
            )
        }
    }

    private func recordEvent(
        module: String,
        level: HQEventLevel,
        message: String,
        outcome: String
    ) {
        let event = HQEventItem(
            timestamp: Self.clockFormatter.string(from: .now),
            module: module.uppercased(),
            level: level,
            message: message,
            outcome: outcome
        )
        commandHistory.insert(event, at: 0)
        if commandHistory.count > 10 {
            commandHistory.removeLast(commandHistory.count - 10)
        }
        events = Array((commandHistory + events).prefix(14))
    }

    private func recordTimelineItem(
        source: String,
        module: String,
        title: String,
        detail: String,
        outcome: String,
        level: HQEventLevel
    ) {
        let item = HQOperationTimelineItem(
            timestamp: .now,
            timestampText: Self.clockFormatter.string(from: .now),
            source: source,
            module: module.uppercased(),
            title: title.uppercased(),
            detail: detail,
            outcome: outcome.uppercased(),
            level: level
        )
        operatorTimeline.insert(item, at: 0)
        if operatorTimeline.count > 12 {
            operatorTimeline.removeLast(operatorTimeline.count - 12)
        }
    }

    private func timelineLevel(for state: HQCommandState) -> HQEventLevel {
        switch state {
        case .failed:
            return .critical
        case .rolledBack:
            return .warning
        case .ready, .executing, .success:
            return .info
        }
    }

    private func refreshSuccessFailureTimestamps(for result: HQCommandState) {
        switch result {
        case .success, .rolledBack:
            globalLastSuccess = .now
        case .failed:
            globalLastFailure = .now
        case .ready, .executing:
            break
        }
        lastSuccessText = globalLastSuccess.map(relativeText) ?? "Yok"
        lastFailureText = globalLastFailure.map(relativeText) ?? "Yok"
    }

    private func showBanner(state: HQCommandState, title: String, detail: String) {
        bannerTask?.cancel()
        banner = HQCommandBannerModel(state: state, title: title, detail: detail)

        guard state != .executing else { return }

        bannerTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3.2))
            guard let self else { return }
            self.banner = nil
        }
    }

    private func emitHaptic(for state: HQCommandState) {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        switch state {
        case .success:
            generator.notificationOccurred(.success)
        case .failed, .rolledBack:
            generator.notificationOccurred(.warning)
        case .executing:
            generator.notificationOccurred(.success)
        case .ready:
            break
        }
        #endif
    }

    private func threatLabel(quantum: QuantumCryptoEngine, blockedIPs: Int) -> String {
        if quantum.qkdStatus == "COMPROMISED" || blockedIPs >= 3 { return "HIGH" }
        if blockedIPs > 0 || quantum.threatLevel.contains("YUKSEK") { return "MED" }
        return "LOW"
    }

    private func activeWorkerCount(env: AppEnvironment) -> Int {
        max(
            1,
            env.bot.activeStrategyCount
            + (env.copyTrade.isActive ? 1 : 0)
            + (env.market.last != nil ? 1 : 0)
            + (env.settings.marketBridgeEnabled ? 1 : 0)
        )
    }

    private func percentageText(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func uptimeText(from date: Date) -> String {
        Self.uptimeFormatter.string(from: date, to: .now) ?? "0m"
    }

    private func relativeText(_ date: Date) -> String {
        Self.relativeFormatter.localizedString(for: date, relativeTo: .now)
    }

    private func relativeClockText(from date: Date?, fallback: String) -> String {
        guard let date else { return fallback }
        let interval = max(0, Int(Date().timeIntervalSince(date)))
        if interval < 60 { return "\(interval) sn" }
        if interval < 3_600 { return "\(interval / 60) dk" }
        return "\(interval / 3_600) sa"
    }

    private func shortClockText(from timestamp: String) -> String {
        if let date = timestampDate(from: timestamp) {
            return Self.clockFormatter.string(from: date)
        }
        return timestamp
    }

    private func timestampDate(from timestamp: String) -> Date? {
        Self.isoFormatterWithFractional.date(from: timestamp)
        ?? Self.isoFormatter.date(from: timestamp)
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    private static let clockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private static let isoFormatterWithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let uptimeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        return formatter
    }()
}
