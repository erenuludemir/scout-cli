import SwiftUI
import Combine

public struct PQCLogEntry: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let protocolName: String
    public let action: String
    public let latencyMs: Double
    public let noiseLevel: Double
    public let isAIOptimized: Bool

    public init(
        id: UUID = UUID(),
        timestamp: Date,
        protocolName: String,
        action: String,
        latencyMs: Double,
        noiseLevel: Double,
        isAIOptimized: Bool
    ) {
        self.id = id
        self.timestamp = timestamp
        self.protocolName = protocolName
        self.action = action
        self.latencyMs = latencyMs
        self.noiseLevel = noiseLevel
        self.isAIOptimized = isAIOptimized
    }

    static func parseTerminalLine(_ line: String) -> PQCLogEntry? {
        let protocolName = knownProtocols.first(where: { line.localizedCaseInsensitiveContains($0) }) ?? "Kyber-768"
        let latency = firstDouble(in: line, regex: latencyRegex)
            ?? firstDouble(in: line, regex: genericMsRegex)
            ?? 0
        let noise = firstDouble(in: line, regex: noiseRegex)
            ?? (line.localizedCaseInsensitiveContains("AI") ? 12.0 : 82.0)
        let isAIOptimized =
            line.localizedCaseInsensitiveContains("AI")
            || line.localizedCaseInsensitiveContains("OPTIMIZED")
            || line.localizedCaseInsensitiveContains("AKTIF")
        let action = actionText(from: line)

        return PQCLogEntry(
            timestamp: Date(),
            protocolName: protocolName,
            action: action,
            latencyMs: latency,
            noiseLevel: noise,
            isAIOptimized: isAIOptimized
        )
    }

    private static func actionText(from line: String) -> String {
        var cleaned = line
        if let firstClose = cleaned.firstIndex(of: "]") {
            cleaned = String(cleaned[cleaned.index(after: firstClose)...]).trimmingCharacters(in: .whitespaces)
        }
        if let secondClose = cleaned.firstIndex(of: "]"), cleaned.first == "[" {
            cleaned = String(cleaned[cleaned.index(after: secondClose)...]).trimmingCharacters(in: .whitespaces)
        }

        if let range = cleaned.range(of: "Gecikme:", options: .caseInsensitive) {
            cleaned = String(cleaned[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let range = cleaned.range(of: "Noise:", options: .caseInsensitive) {
            cleaned = String(cleaned[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let range = cleaned.range(of: "Gurultu:", options: .caseInsensitive) {
            cleaned = String(cleaned[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        return cleaned.isEmpty ? "Log Update" : cleaned
    }

    private static func firstDouble(in text: String, regex: NSRegularExpression) -> Double? {
        let range = NSRange(text.startIndex..., in: text)
        guard
            let match = regex.firstMatch(in: text, range: range),
            let valueRange = Range(match.range(at: 1), in: text)
        else {
            return nil
        }
        return Double(text[valueRange])
    }

    private static let knownProtocols = ["Kyber-512", "Kyber-768", "Kyber-1024", "Dilithium2", "Dilithium3", "Falcon-512", "SPHINCS+"]
    private static let latencyRegex = try! NSRegularExpression(pattern: #"Gecikme:\s*([0-9]+(?:\.[0-9]+)?)ms"#, options: [.caseInsensitive])
    private static let genericMsRegex = try! NSRegularExpression(pattern: #"([0-9]+(?:\.[0-9]+)?)ms"#, options: [.caseInsensitive])
    private static let noiseRegex = try! NSRegularExpression(pattern: #"(?:Noise|Gurultu):\s*([0-9]+(?:\.[0-9]+)?)%?"#, options: [.caseInsensitive])
}

struct QuantumMetricsSnapshot: Equatable {
    let averageLatency: Double
    let averageNoise: Double
    let qkdKeyRate: Double
    let pqcLatency: Double
    let nisqNoiseLevel: Double
    let multiplierText: String
    let threatLevel: String

    static func reduce(logs: [PQCLogEntry], isAIOptimized: Bool, qkdStatus: String) -> QuantumMetricsSnapshot {
        let activeLogs = Array(logs.suffix(12))
        let averageLatency = activeLogs.isEmpty ? (isAIOptimized ? 12.5 : 145.0) : activeLogs.map(\.latencyMs).reduce(0, +) / Double(activeLogs.count)
        let averageNoise = activeLogs.isEmpty ? (isAIOptimized ? 15.0 : 82.0) : activeLogs.map(\.noiseLevel).reduce(0, +) / Double(activeLogs.count)

        let latencyFactor = max(0.15, min(1.0, 160.0 / max(averageLatency, 1.0)))
        let noiseFactor = max(0.15, min(1.0, 100.0 / max(averageNoise, 1.0)))

        let qkdKeyRate: Double
        let multiplierText: String

        if isAIOptimized {
            qkdKeyRate = 120.0 + (latencyFactor * noiseFactor * 1_080.0)
            multiplierText = "\(max(100, Int(qkdKeyRate / 1.2)))x"
        } else {
            qkdKeyRate = max(1.2, 1.2 + (latencyFactor * noiseFactor * 3.8))
            multiplierText = "1x"
        }

        let pqcReady = PQCGuard.validateKeyLength(algorithm: "AES", length: 256)
        let threatLevel: String

        if qkdStatus == "COMPROMISED" {
            threatLevel = "KRITIK (QKD HATTI KOMPROMIZE)"
        } else if !pqcReady {
            threatLevel = "YUKSEK (PQC ANAHTAR PROFILI YETERSIZ)"
        } else if isAIOptimized && averageNoise < 20 {
            threatLevel = "NOTR (PQC + QKD ZIRHI AKTIF)"
        } else if averageNoise < 45 {
            threatLevel = "GOZLEM (PQC HATTI STABILIZE OLUYOR)"
        } else {
            threatLevel = "YUKSEK (KUANTUM SALDIRI RISKI)"
        }

        return QuantumMetricsSnapshot(
            averageLatency: averageLatency,
            averageNoise: averageNoise,
            qkdKeyRate: qkdKeyRate,
            pqcLatency: averageLatency,
            nisqNoiseLevel: averageNoise,
            multiplierText: multiplierText,
            threatLevel: threatLevel
        )
    }
}

@MainActor
public struct QuantumTrainingProgressSnapshot: Equatable {
    let progressValue: Double
    let currentStep: TrainingJourneyStep
    let currentStepTitle: String
    let estimatedMinutesRemaining: Int
    let selectedRoleTitle: String
    let selectedModeTitle: String
    let selectedModuleTitles: [String]
    let canAdvance: Bool
    let blockingReason: String?
    let quizScore: Int
    let quizTotal: Int
    let completionCount: Int
    let hasCompletedJourney: Bool
    private static let quizQuestionCount = 3

    static let idle = QuantumTrainingProgressSnapshot(
        progressValue: 0,
        currentStep: .welcome,
        currentStepTitle: TrainingJourneyStep.welcome.title,
        estimatedMinutesRemaining: TrainingJourneyStep.allCases.count * 2,
        selectedRoleTitle: TrainingRole.technical.title,
        selectedModeTitle: TrainingMode.quickTour.title,
        selectedModuleTitles: [],
        canAdvance: true,
        blockingReason: nil,
        quizScore: 0,
        quizTotal: quizQuestionCount,
        completionCount: 0,
        hasCompletedJourney: false
    )

    static func reduce(journey: TrainingJourneyStore) -> QuantumTrainingProgressSnapshot {
        QuantumTrainingProgressSnapshot(
            progressValue: journey.progressValue,
            currentStep: journey.currentStep,
            currentStepTitle: journey.currentStep.title,
            estimatedMinutesRemaining: journey.estimatedMinutesRemaining,
            selectedRoleTitle: journey.selectedRole.title,
            selectedModeTitle: journey.selectedMode.title,
            selectedModuleTitles: journey.selectedModuleTitles,
            canAdvance: journey.canAdvance,
            blockingReason: journey.blockingReason,
            quizScore: journey.quizScore,
            quizTotal: quizQuestionCount,
            completionCount: journey.analytics.completionCount,
            hasCompletedJourney: journey.hasCompletedJourney
        )
    }
}

@MainActor
public final class PQCLogService {
    public static let shared = PQCLogService()

    public var logPublisher: AnyPublisher<PQCLogEntry, Never> {
        subject.eraseToAnyPublisher()
    }

    private enum SourceMode {
        case simulator
        case external
    }

    private let subject = PassthroughSubject<PQCLogEntry, Never>()
    private var streamTask: Task<Void, Never>?
    private var externalFeedCancellable: AnyCancellable?
    private var sourceMode: SourceMode = .simulator

    private let protocols = ["Kyber-512", "Kyber-768", "Kyber-1024", "Dilithium2", "Dilithium3", "Falcon-512"]
    private let actions = ["KeyGen", "Encapsulation", "Decapsulation", "Signature Verify"]

    public init() {}

    public func useSimulator() {
        externalFeedCancellable?.cancel()
        externalFeedCancellable = nil
        sourceMode = .simulator
    }

    public func bindExternalFeed(_ publisher: AnyPublisher<PQCLogEntry, Never>) {
        stopReading()
        sourceMode = .external
        externalFeedCancellable = publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] entry in
                self?.subject.send(entry)
            }
    }

    public func startReadingLogs(aiEnabled: Bool) {
        guard sourceMode == .simulator else { return }

        streamTask?.cancel()
        let protocols = self.protocols
        let actions = self.actions

        streamTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard let self else { return }

                let protocolName = protocols.randomElement() ?? "Kyber-768"
                let action = actions.randomElement() ?? "Encapsulation"
                let baseLatency = protocolName.contains("Kyber") ? 45.0 : 120.0
                let latency = aiEnabled ? Double.random(in: 8.0 ... 15.0) : Double.random(in: baseLatency ... (baseLatency + 50.0))
                let noise = aiEnabled ? Double.random(in: 2.0 ... 12.0) : Double.random(in: 60.0 ... 85.0)

                let entry = PQCLogEntry(
                    timestamp: Date(),
                    protocolName: protocolName,
                    action: action,
                    latencyMs: latency,
                    noiseLevel: noise,
                    isAIOptimized: aiEnabled
                )

                self.subject.send(entry)
            }
        }
    }

    public func stopReading() {
        streamTask?.cancel()
        streamTask = nil
    }
}

@MainActor
public final class QuantumCryptoEngine: ObservableObject {
    public static let shared = QuantumCryptoEngine(logService: .shared)

    @Published public private(set) var recentLogs: [PQCLogEntry] = []
    @Published public private(set) var qkdKeyRate: Double = 1.2
    @Published public private(set) var pqcLatency: Double = 145.0
    @Published public private(set) var nisqNoiseLevel: Double = 82.0
    @Published public private(set) var averageLatency: Double = 145.0
    @Published public private(set) var averageNoise: Double = 82.0
    @Published public private(set) var qkdStatus: String = "ESTABLISHED"
    @Published public private(set) var threatLevel: String = "YUKSEK (KUANTUM SALDIRI RISKI)"
    @Published public private(set) var isAIOptimized = false
    @Published public private(set) var isSyncing = false
    @Published public private(set) var multiplierText = "1x"
    @Published public private(set) var backtrackingEvaluation: QuantumBacktrackingEvaluation = .idle
    @Published public private(set) var hierarchySnapshot: QuantumHierarchySnapshot = .idle
    @Published public private(set) var trainingSnapshot: QuantumTrainingProgressSnapshot = .idle

    private let logService: PQCLogService
    private let securityProvider: QuantumSecurityProvider
    private let planner = QuantumBacktrackingPlanner()
    private var syncTask: Task<Void, Never>?
    private var optimizationTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var trainingCancellable: AnyCancellable?
    private let maxRetainedLogs = 24
    private var lastOptimizationSignature: QuantumWorkloadMetrics.Signature?
    private var boundTrainingJourneyID: ObjectIdentifier?

    public init(
        logService: PQCLogService,
        securityProvider: QuantumSecurityProvider = .shared
    ) {
        self.logService = logService
        self.securityProvider = securityProvider

        logService.logPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] log in
                self?.handleNewLog(log)
            }
            .store(in: &cancellables)

        logService.useSimulator()
        logService.startReadingLogs(aiEnabled: false)
        rebuildMetrics()
    }

    deinit {
        syncTask?.cancel()
        optimizationTask?.cancel()
        trainingCancellable?.cancel()
    }

    public func bindTrainingJourney(_ journey: TrainingJourneyStore) {
        let journeyID = ObjectIdentifier(journey)
        guard boundTrainingJourneyID != journeyID else { return }

        boundTrainingJourneyID = journeyID
        trainingCancellable?.cancel()
        updateTrainingSnapshot(from: journey)

        trainingCancellable = journey.objectWillChange
            .sink { [weak self, weak journey] _ in
                guard let self, let journey else { return }
                Task { @MainActor [weak self, weak journey] in
                    guard let self, let journey else { return }
                    self.updateTrainingSnapshot(from: journey)
                }
            }
    }

    public func toggleAIOptimization() {
        guard !isSyncing else { return }

        let nextState = !isAIOptimized
        isSyncing = true
        syncTask?.cancel()

        syncTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(1_500))
            guard let self else { return }

            let qkdExchange = securityProvider.initiateQKDExchange()
            self.qkdStatus = qkdExchange.status
            self.isAIOptimized = nextState
            self.logService.startReadingLogs(aiEnabled: nextState)
            if nextState {
                CognitiveTwinRegistry.shared.mentorHeir(currentHeirAgeMonths: 54)
                BarakfakihCitadel.shared.fortifyPhysicalAnchor()
                TelepathyGateway.shared.processBrainwaveCommand(intentCode: "INTENT_QKD_MONITOR")
            } else {
                TelepathyGateway.shared.processBrainwaveCommand(intentCode: "INTENT_MONITOR")
            }
            self.rebuildMetrics()
            self.isSyncing = false
        }
    }

    private func handleNewLog(_ log: PQCLogEntry) {
        recentLogs.append(log)
        if recentLogs.count > maxRetainedLogs {
            recentLogs.removeFirst(recentLogs.count - maxRetainedLogs)
        }
        rebuildMetrics()
    }

    private func rebuildMetrics() {
        let snapshot = QuantumMetricsSnapshot.reduce(
            logs: recentLogs,
            isAIOptimized: isAIOptimized,
            qkdStatus: qkdStatus
        )

        averageLatency = snapshot.averageLatency
        averageNoise = snapshot.averageNoise
        qkdKeyRate = snapshot.qkdKeyRate
        pqcLatency = snapshot.pqcLatency
        nisqNoiseLevel = snapshot.nisqNoiseLevel
        multiplierText = snapshot.multiplierText
        threatLevel = snapshot.threatLevel
        scheduleOptimizationPass()
    }

    private func updateTrainingSnapshot(from journey: TrainingJourneyStore) {
        trainingSnapshot = QuantumTrainingProgressSnapshot.reduce(journey: journey)
        scheduleOptimizationPass()
    }

    private func scheduleOptimizationPass() {
        let workload = QuantumWorkloadMetrics(
            averageLatency: averageLatency,
            averageNoise: averageNoise,
            qkdStatus: qkdStatus,
            isAIOptimized: isAIOptimized,
            retainedLogCount: recentLogs.count,
            branchFactor: averageNoise > 65 ? 3 : 2,
            searchDepth: isAIOptimized ? 4 : 5,
            precision: isAIOptimized ? 6 : 4,
            trainingProgress: trainingSnapshot.progressValue,
            trainingStepIndex: trainingSnapshot.currentStep.rawValue,
            trainingCurrentStepTitle: trainingSnapshot.currentStepTitle,
            trainingCanAdvance: trainingSnapshot.canAdvance,
            trainingBlockingReason: trainingSnapshot.blockingReason,
            trainingSelectedModuleCount: trainingSnapshot.selectedModuleTitles.count,
            trainingCompletionCount: trainingSnapshot.completionCount
        )

        let signature = workload.signature
        guard signature != lastOptimizationSignature else { return }
        lastOptimizationSignature = signature
        optimizationTask?.cancel()

        optimizationTask = Task.detached(priority: .utility) { [planner] in
            let plan = await planner.optimize(workload: workload)
            await MainActor.run { [weak self] in
                guard let self else { return }
                guard self.lastOptimizationSignature == signature else { return }
                self.backtrackingEvaluation = plan.evaluation
                self.hierarchySnapshot = plan.hierarchy
            }
        }
    }
}

public struct QuantumPerformanceDashboard: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @StateObject private var engine: QuantumCryptoEngine
    @ObservedObject private var twin = CognitiveTwinRegistry.shared
    @ObservedObject private var citadel = BarakfakihCitadel.shared
    @ObservedObject private var telepathy = TelepathyGateway.shared
    private let showsBackButton: Bool

    @MainActor
    public init(showsBackButton: Bool = false) {
        _engine = StateObject(wrappedValue: QuantumCryptoEngine.shared)
        self.showsBackButton = showsBackButton
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: QAITokens.Spacing.l) {
                ScreenHeader(
                    title: "Quantum Ops",
                    showsBackButton: showsBackButton,
                    onBack: { dismiss() }
                )

                QuantumThreatCard(engine: engine)
                QuantumMetricsGrid(engine: engine)
                QuantumBacktrackingCard(engine: engine)
                QuantumTrainingCard(engine: engine)
                QuantumHierarchyCard(engine: engine)
                QuantumAutonomyCard(twin: twin, citadel: citadel, telepathy: telepathy)
                QuantumControlCard(engine: engine)
                BursaHQTerminalView(bindToMetrics: true)
            }
            .padding(.horizontal, QAITokens.Layout.screenPadding)
            .padding(.top, QAITokens.Spacing.s)
            .padding(.bottom, QAITokens.Layout.dockedBottomClearance)
        }
        .accessibilityIdentifier("quantum-ops-screen")
        .background(AppBackground())
        .screenNavigationChromeHidden()
        .task {
            engine.bindTrainingJourney(env.trainingJourney)
        }
    }
}

private struct QuantumAutonomyCard: View {
    @ObservedObject var twin: CognitiveTwinRegistry
    @ObservedObject var citadel: BarakfakihCitadel
    @ObservedObject var telepathy: TelepathyGateway

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                Text("Autonomy Overlays")
                    .font(QAITokens.Typography.cardTitle)
                    .foregroundStyle(QAITokens.Palette.textPrimary)

                Text("Digital twin, smart citadel ve neural command raili ayni quantum workload ustunde aggregate state ile beslenir.")
                    .font(QAITokens.Typography.body)
                    .foregroundStyle(QAITokens.Palette.textSecondary)
                    .lineLimit(nil)

                NavigationLink {
                    DigitalTwinView(showsBackButton: true)
                } label: {
                    QuantumAutonomyRow(
                        title: "Digital Twin",
                        subtitle: twin.statusText,
                        value: "%\(Int(twin.syncProgress * 100))",
                        tint: QAITokens.Palette.chipBlue
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    CitadelStatusView(showsBackButton: true)
                } label: {
                    QuantumAutonomyRow(
                        title: "Smart Citadel",
                        subtitle: citadel.uplinkStatus,
                        value: citadel.isSealed ? "LOCKED" : "STANDBY",
                        tint: QAITokens.Palette.chipAmber
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    NeuralCommandView(showsBackButton: true)
                } label: {
                    QuantumAutonomyRow(
                        title: "Neural Command",
                        subtitle: telepathy.lastIntentCode,
                        value: String(format: "%.3f ms", telepathy.lastLatencyMs),
                        tint: QAITokens.Palette.chipTeal
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct QuantumThreatCard: View {
    @ObservedObject var engine: QuantumCryptoEngine

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("KRIPTOGRAFI AGI")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(QAITokens.Palette.textSecondary)
                        Text("QKD / PQC Performans")
                            .font(QAITokens.Typography.largeTitle)
                            .foregroundStyle(QAITokens.Palette.textPrimary)
                    }

                    Spacer()

                    Circle()
                        .fill(statusColor)
                        .frame(width: 12, height: 12)
                        .shadow(color: statusColor.opacity(0.7), radius: 6)
                }

                HStack(spacing: QAITokens.Spacing.s) {
                    TerminalBadge(title: engine.qkdStatus, tint: QAITokens.Palette.chipBlue)
                    TerminalBadge(title: engine.multiplierText, tint: QAITokens.Palette.gold)
                    TerminalBadge(title: engine.isAIOptimized ? "AI OPTIMIZED" : "CLASSIC MODE", tint: QAITokens.Palette.chipTeal)
                }

                HStack(alignment: .center, spacing: QAITokens.Spacing.m) {
                    Image(systemName: engine.isAIOptimized ? "shield.checkered" : "exclamationmark.triangle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(statusColor)

                    Text(engine.threatLevel)
                        .font(QAITokens.Typography.bodyStrong)
                        .foregroundStyle(statusColor)
                        .lineLimit(nil)
                }
                .padding(QAITokens.Spacing.m)
                .background(Color.black.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private var statusColor: Color {
        if engine.isSyncing {
            return QAITokens.Palette.warning
        }
        return engine.isAIOptimized ? QAITokens.Palette.teal : Color.red.opacity(0.9)
    }
}

private struct QuantumMetricsGrid: View {
    @ObservedObject var engine: QuantumCryptoEngine

    private let columns = [
        GridItem(.flexible(), spacing: QAITokens.Spacing.s),
        GridItem(.flexible(), spacing: QAITokens.Spacing.s)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: QAITokens.Spacing.s) {
            QuantumMetricCard(title: "QKD Anahtar Uretimi", value: engine.qkdKeyRate, unit: "kbps", icon: "key.fill", tint: .cyan, trendUp: engine.isAIOptimized)
            QuantumMetricCard(title: "PQC Gecikmesi", value: engine.pqcLatency, unit: "ms", icon: "timer", tint: .orange, trendUp: engine.pqcLatency <= 20)
            QuantumMetricCard(title: "NISQ Gurultu", value: engine.nisqNoiseLevel, unit: "%", icon: "waveform.path.ecg", tint: .purple, trendUp: engine.nisqNoiseLevel <= 20)
            QuantumMetricCard(title: "Ort. Gecikme", value: engine.averageLatency, unit: "ms", icon: "speedometer", tint: QAITokens.Palette.gold, trendUp: engine.averageLatency <= 20)
        }
    }
}

private struct QuantumControlCard: View {
    @ObservedObject var engine: QuantumCryptoEngine

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                Text("Neural Crypto Control")
                    .font(QAITokens.Typography.cardTitle)
                    .foregroundStyle(QAITokens.Palette.textPrimary)

                Text("PQC log akisi simdi capped buffer ile tutuluyor. Gercek feed baglamak icin PQCLogService.bindExternalFeed(...) kullan.")
                    .font(QAITokens.Typography.body)
                    .foregroundStyle(QAITokens.Palette.textSecondary)
                    .lineLimit(nil)

                PrimaryActionButton(
                    title: engine.isSyncing
                        ? "Senkronize Ediliyor..."
                        : (engine.isAIOptimized ? "AI Optimizasyonunu Kapat" : "AI Optimizasyonunu Baslat"),
                    style: engine.isAIOptimized ? .secondary : .primary
                ) {
                    engine.toggleAIOptimization()
                }
                .disabled(engine.isSyncing)

                Text("PQC, QKD, kuantum yurumesi ve hierarchy optimizer sabit maliyetli utility task uzerinden beslenir; UI tarafinda log ve tree sonucu sinirli buffer ile tutulur.")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(QAITokens.Palette.textSecondary)
                    .lineLimit(nil)
            }
        }
    }
}

private struct QuantumBacktrackingCard: View {
    @ObservedObject var engine: QuantumCryptoEngine

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tree Quantum Operations")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(QAITokens.Palette.textSecondary)
                        Text("Backtracking Quantum Walk")
                            .font(QAITokens.Typography.cardTitle)
                            .foregroundStyle(QAITokens.Palette.textPrimary)
                    }
                    Spacer()
                    TerminalBadge(
                        title: engine.backtrackingEvaluation.activeOperators.isEmpty
                            ? "IDLE"
                            : engine.backtrackingEvaluation.activeOperators.map(\.rawValue).joined(separator: " "),
                        tint: QAITokens.Palette.chipBlue
                    )
                }

                HStack(spacing: QAITokens.Spacing.s) {
                    QuantumInlineStat(title: "Phase", value: String(format: "%.4f", engine.backtrackingEvaluation.estimatedPhase))
                    QuantumInlineStat(title: "Nodes", value: "\(engine.backtrackingEvaluation.evaluatedNodes)")
                    QuantumInlineStat(title: "Rejected", value: "\(engine.backtrackingEvaluation.rejectedNodes)")
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Cozum yolu")
                        .font(QAITokens.Typography.caption)
                        .foregroundStyle(QAITokens.Palette.textSecondary)
                    Text(solutionText)
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(QAITokens.Palette.textPrimary)
                        .lineLimit(nil)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(engine.backtrackingEvaluation.symbolicComplexity)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(QAITokens.Palette.gold)
                    Text("\(engine.backtrackingEvaluation.graphSummary) | work≈\(Int(engine.backtrackingEvaluation.workEstimate.rounded()))")
                        .font(QAITokens.Typography.caption)
                        .foregroundStyle(QAITokens.Palette.textSecondary)
                        .lineLimit(nil)
                }
            }
        }
    }

    private var solutionText: String {
        guard let path = engine.backtrackingEvaluation.solutionPath, !path.isEmpty else {
            return "Quantum walk simdilik kararsiz; hierarchy fallback aktif."
        }
        return path.map(String.init).joined(separator: " -> ")
    }
}

private struct QuantumTrainingCard: View {
    @ObservedObject var engine: QuantumCryptoEngine

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Trading Blockchain Training")
                            .font(QAITokens.Typography.cardTitle)
                            .foregroundStyle(QAITokens.Palette.textPrimary)
                        Text(engine.trainingSnapshot.currentStepTitle)
                            .font(QAITokens.Typography.bodyStrong)
                            .foregroundStyle(QAITokens.Palette.textPrimary)
                    }

                    Spacer()

                    Text("%\(Int(engine.trainingSnapshot.progressValue * 100))")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(QAITokens.Palette.gold)
                }

                ProgressView(value: engine.trainingSnapshot.progressValue)
                    .tint(QAITokens.Palette.gold)

                HStack(spacing: QAITokens.Spacing.s) {
                    QuantumInlineStat(title: "Rol", value: engine.trainingSnapshot.selectedRoleTitle)
                    QuantumInlineStat(title: "Mod", value: engine.trainingSnapshot.selectedModeTitle)
                    QuantumInlineStat(title: "Kalan", value: "\(engine.trainingSnapshot.estimatedMinutesRemaining) dk")
                }

                if !engine.trainingSnapshot.selectedModuleTitles.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Secili moduller")
                            .font(QAITokens.Typography.caption)
                            .foregroundStyle(QAITokens.Palette.textSecondary)

                        FlexibleChipWrap(items: engine.trainingSnapshot.selectedModuleTitles)
                    }
                }

                if let blockingReason = engine.trainingSnapshot.blockingReason {
                    Text(blockingReason)
                        .font(QAITokens.Typography.caption)
                        .foregroundStyle(QAITokens.Palette.warning)
                        .lineLimit(nil)
                } else {
                    Text(engine.trainingSnapshot.hasCompletedJourney
                        ? "Journey tamamlandi. Quantum hierarchy artik tamamlanmis egitim profilini kullaniyor."
                        : "Journey ilerlemeye hazir. Quantum hierarchy gercek progress verisi ile yeniden agirliklandirildi.")
                        .font(QAITokens.Typography.caption)
                        .foregroundStyle(QAITokens.Palette.textSecondary)
                        .lineLimit(nil)
                }

                HStack(spacing: QAITokens.Spacing.s) {
                    QuantumInlineStat(title: "Quiz", value: "\(engine.trainingSnapshot.quizScore)/\(engine.trainingSnapshot.quizTotal)")
                    QuantumInlineStat(title: "Secim", value: "\(engine.trainingSnapshot.selectedModuleTitles.count)")
                    QuantumInlineStat(title: "Tamam", value: "\(engine.trainingSnapshot.completionCount)")
                }

                if #available(iOS 17.0, macOS 14.0, *) {
                    NavigationLink {
                        TrainingJourneyView(showsCloseButton: false)
                    } label: {
                        HStack {
                            Text("Training journey'e git")
                                .font(QAITokens.Typography.bodyStrong)
                                .foregroundStyle(QAITokens.Palette.textPrimary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(QAITokens.Palette.gold)
                        }
                        .padding(QAITokens.Spacing.m)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct QuantumHierarchyCard: View {
    @ObservedObject var engine: QuantumCryptoEngine

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                Text("Project Priorities")
                    .font(QAITokens.Typography.cardTitle)
                    .foregroundStyle(QAITokens.Palette.textPrimary)

                Text(engine.hierarchySnapshot.headline)
                    .font(QAITokens.Typography.bodyStrong)
                    .foregroundStyle(QAITokens.Palette.textPrimary)
                    .lineLimit(nil)

                Text(engine.hierarchySnapshot.dispatchMode)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(QAITokens.Palette.textSecondary)
                    .lineLimit(nil)

                ForEach(engine.hierarchySnapshot.priorities) { priority in
                    HStack(alignment: .top, spacing: QAITokens.Spacing.s) {
                        TerminalBadge(title: badgeText(for: priority.level), tint: badgeTint(for: priority.level))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(priority.title)
                                .font(QAITokens.Typography.bodyStrong)
                                .foregroundStyle(QAITokens.Palette.textPrimary)
                            Text(priority.detail)
                                .font(QAITokens.Typography.caption)
                                .foregroundStyle(QAITokens.Palette.textSecondary)
                                .lineLimit(nil)
                            Text(priority.route)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(QAITokens.Palette.gold)
                        }
                    }
                }
            }
        }
    }

    private func badgeText(for level: QuantumProjectPriorityLevel) -> String {
        switch level {
        case .critical: "CRITICAL"
        case .high: "HIGH"
        case .medium: "MEDIUM"
        case .low: "LOW"
        }
    }

    private func badgeTint(for level: QuantumProjectPriorityLevel) -> Color {
        switch level {
        case .critical: Color.red.opacity(0.85)
        case .high: QAITokens.Palette.warning
        case .medium: QAITokens.Palette.chipBlue
        case .low: QAITokens.Palette.chipTeal
        }
    }
}

private struct FlexibleChipWrap: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(chunked(items, size: 2), id: \.self) { row in
                HStack(spacing: QAITokens.Spacing.s) {
                    ForEach(row, id: \.self) { item in
                        Text(item)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(QAITokens.Palette.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(QAITokens.Palette.cardElevated)
                            .clipShape(Capsule())
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if row.count == 1 {
                        Spacer()
                    }
                }
            }
        }
    }

    private func chunked(_ items: [String], size: Int) -> [[String]] {
        stride(from: 0, to: items.count, by: size).map { index in
            Array(items[index ..< min(index + size, items.count)])
        }
    }
}

private struct QuantumInlineStat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(QAITokens.Typography.caption)
                .foregroundStyle(QAITokens.Palette.textSecondary)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(QAITokens.Palette.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(QAITokens.Spacing.s)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct QuantumMetricCard: View {
    let title: String
    let value: Double
    let unit: String
    let icon: String
    let tint: Color
    let trendUp: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: QAITokens.Spacing.s) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                Spacer()
                Image(systemName: trendUp ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(trendUp ? QAITokens.Palette.teal : Color.red.opacity(0.9))
            }

            Text(valueText)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(QAITokens.Palette.textPrimary)

            Text(unit)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(tint)

            Text(title)
                .font(QAITokens.Typography.caption)
                .foregroundStyle(QAITokens.Palette.textSecondary)
                .lineLimit(2)
        }
        .padding(QAITokens.Spacing.m)
        .frame(maxWidth: .infinity, minHeight: 156, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }

    private var valueText: String {
        String(format: "%.1f", value)
    }
}

private struct QuantumAutonomyRow: View {
    let title: String
    let subtitle: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: QAITokens.Spacing.s) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(QAITokens.Typography.bodyStrong)
                    .foregroundStyle(QAITokens.Palette.textPrimary)
                Text(subtitle)
                    .font(QAITokens.Typography.caption)
                    .foregroundStyle(QAITokens.Palette.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(QAITokens.Palette.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(tint)
                .clipShape(Capsule())
        }
        .padding(QAITokens.Spacing.s)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct TerminalBadge: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(QAITokens.Palette.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(tint)
            .clipShape(Capsule())
    }
}

#Preview {
    NavigationStack {
        QuantumPerformanceDashboard(showsBackButton: true)
            .environmentObject(AppEnvironment.liveInSim())
    }
}
