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

    private let logService: PQCLogService
    private let securityProvider: QuantumSecurityProvider
    private var syncTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private let maxRetainedLogs = 24

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
    }
}

public struct QuantumPerformanceDashboard: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var engine: QuantumCryptoEngine
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
                QuantumControlCard(engine: engine)
                QuantumTerminalCard(logs: Array(engine.recentLogs.reversed()))
            }
            .padding(.horizontal, QAITokens.Layout.screenPadding)
            .padding(.top, QAITokens.Spacing.s)
            .padding(.bottom, QAITokens.Layout.dockedBottomClearance)
        }
        .accessibilityIdentifier("quantum-ops-screen")
        .background(AppBackground())
        .screenNavigationChromeHidden()
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

                Text("PQC, QKD ve terminal akisi sabit maliyetli bir utility task uzerinden beslenir; UI tarafinda sadece son 24 log tutulur.")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(QAITokens.Palette.textSecondary)
                    .lineLimit(nil)
            }
        }
    }
}

private struct QuantumTerminalCard: View {
    let logs: [PQCLogEntry]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                HStack {
                    Image(systemName: "terminal")
                        .foregroundStyle(Color.green)
                    Text("CANLI PQC AKISI")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.green)
                    Spacer()
                    Text("tail -f pqc_node.log")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.green.opacity(0.7))
                }

                VStack(alignment: .leading, spacing: 8) {
                    if logs.isEmpty {
                        Text("[bootstrap] log akisi bekleniyor")
                            .foregroundStyle(Color.green.opacity(0.85))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                    } else {
                        ForEach(logs.prefix(15)) { log in
                            QuantumTerminalRow(log: log)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(QAITokens.Spacing.m)
                .background(Color.black.opacity(0.92))
                .clipShape(RoundedRectangle(cornerRadius: QAITokens.Radius.button, style: .continuous))
            }
        }
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

private struct QuantumTerminalRow: View {
    let log: PQCLogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("[\(log.timestamp, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits).secondFraction(.fractional(3)))]")
                .foregroundStyle(Color.gray)

            Text("[\(log.protocolName)]")
                .foregroundStyle(log.isAIOptimized ? Color.cyan : Color.yellow)

            Text(log.action)
                .foregroundStyle(Color.white)

            Spacer(minLength: 8)

            Text(String(format: "%.1fms", log.latencyMs))
                .foregroundStyle(log.latencyMs > 50 ? Color.red.opacity(0.9) : QAITokens.Palette.teal)
        }
        .font(.system(size: 11, weight: .medium, design: .monospaced))
        .lineLimit(1)
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
    }
}
