import SwiftUI

@MainActor
final class MegaPipelineMasterModel: ObservableObject {
    @Published var vaultBalance: Double = 84_592_410.50
    @Published var interceptedThreats: Int = 1402
    @Published var qkdKeyRate: Double = 850.5
    @Published var pqcLatency: Double = 12.4
    @Published var heirSyncLevel: Double = 0.99
    @Published var heirMaturityIndex: Double = 0.15
    @Published var currentTransferModule = "Foundation / Quantum Security"
    @Published var alphaWave: Double = 7.83
    @Published var gammaWave: Double = 40.0
    @Published var agents: [MegaPipelineAgentSnapshot] = [
        .init(name: "Araştırma", role: "Dokümantasyon ve repo taraması", status: .active, icon: "network"),
        .init(name: "Sistem Tasarımı", role: "Mimari ve hacim projeksiyonu", status: .active, icon: "cpu"),
        .init(name: "Swarm Orkestratör", role: "Alt ajan dağıtımı ve denetim", status: .standby, icon: "square.grid.3x3.fill")
    ]

    private var timer: Timer?

    init() {
        startPulses()
    }

    deinit {
        timer?.invalidate()
    }

    func issueNeuralOverride() {
        GlobalSinirSistemi.paylasilan.veriPompala(
            kategori: .sistem,
            mesaj: "Mega Pipeline neural override tetiklendi",
            veri: ["intent": "hyper-drive", "origin": "mega-pipeline-master"]
        )
        agents[2].status = .executing
    }

    private func startPulses() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }

    private func tick() {
        vaultBalance += Double.random(in: 2.0 ... 15.0)
        qkdKeyRate = max(640, min(980, qkdKeyRate + Double.random(in: -8 ... 8)))
        pqcLatency = max(7, min(18, pqcLatency + Double.random(in: -0.8 ... 0.8)))
        alphaWave = 7.0 + Double.random(in: 0 ... 1.5)
        gammaWave = 38.0 + Double.random(in: 0 ... 4.5)
        heirMaturityIndex = min(1, heirMaturityIndex + 0.0008)

        if Int.random(in: 1 ... 6) == 1 {
            interceptedThreats += 1
        }

        if agents[2].status == .executing, Int.random(in: 1 ... 3) == 1 {
            agents[2].status = .active
        }
    }
}
struct MegaPipelineAgentSnapshot: Identifiable {
    enum Status: String {
        case active = "Çalışıyor"
        case standby = "Beklemede"
        case executing = "Yürütülüyor"

        var tint: Color {
            switch self {
            case .active:
                return QAITokens.Palette.chipTeal
            case .standby:
                return QAITokens.Palette.cardElevated
            case .executing:
                return QAITokens.Palette.gold.opacity(0.22)
            }
        }
    }

    let id = UUID()
    let name: String
    let role: String
    var status: Status
    let icon: String
}

public struct MegaPipelineMasterView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var sinir = GlobalSinirSistemi.paylasilan
    @StateObject private var model = MegaPipelineMasterModel()

    public init() {}

    public var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: QAITokens.Spacing.l) {
                ScreenHeader(title: "Mega Pipeline", showsBackButton: true, onBack: { dismiss() })

                MegaPipelineHeroCard(model: model)
                MegaPipelineMetricsGrid(model: model)
                MegaPipelineCognitiveCard(model: model)
                MegaPipelineNeuralCard(model: model, telemetry: Array(sinir.telemetryLog.prefix(6)))
                MegaPipelineAgentsCard(agents: model.agents)
            }
            .padding(.horizontal, QAITokens.Layout.screenPadding)
            .padding(.top, QAITokens.Spacing.s)
            .padding(.bottom, QAITokens.Layout.dockedBottomClearance)
        }
        .background(AppBackground())
        .screenNavigationChromeHidden()
    }
}

private struct MegaPipelineHeroCard: View {
    @ObservedObject var model: MegaPipelineMasterModel

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                Text("Merkezi sinir, kasa, PQC savunma ve ajan orkestrasyonu tek yüzeyde.")
                    .font(QAITokens.Typography.cardTitle)
                    .foregroundStyle(QAITokens.Palette.textPrimary)
                    .lineLimit(nil)

                Text("Gerçek runtime omurgası artık yerel FastAPI servisine bağlı. Bu yüzey operasyon akışını, kılavuzu ve canlı telemetriyi birlikte gösterir.")
                    .font(QAITokens.Typography.body)
                    .foregroundStyle(QAITokens.Palette.textSecondary)
                    .lineLimit(nil)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: QAITokens.Spacing.m) {
                        MegaPipelinePill(title: "AUM", value: currency(model.vaultBalance), tint: QAITokens.Palette.chipTeal)
                        MegaPipelinePill(title: "PQC", value: "\(model.interceptedThreats)", tint: QAITokens.Palette.gold.opacity(0.22))
                        MegaPipelinePill(title: "QKD", value: "\(Int(model.qkdKeyRate)) kbps", tint: QAITokens.Palette.chipBlue)
                    }

                    VStack(spacing: QAITokens.Spacing.s) {
                        MegaPipelinePill(title: "AUM", value: currency(model.vaultBalance), tint: QAITokens.Palette.chipTeal)
                        MegaPipelinePill(title: "PQC", value: "\(model.interceptedThreats)", tint: QAITokens.Palette.gold.opacity(0.22))
                        MegaPipelinePill(title: "QKD", value: "\(Int(model.qkdKeyRate)) kbps", tint: QAITokens.Palette.chipBlue)
                    }
                }
            }
        }
    }

    private func currency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}

private struct MegaPipelineMetricsGrid: View {
    @ObservedObject var model: MegaPipelineMasterModel
    private let columns = [GridItem(.adaptive(minimum: 150), spacing: QAITokens.Spacing.s)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: QAITokens.Spacing.s) {
            MegaPipelineMetricCard(title: "PQC Gecikmesi", value: String(format: "%.1f ms", model.pqcLatency), tint: QAITokens.Palette.gold)
            MegaPipelineMetricCard(title: "Alfa Frekansı", value: String(format: "%.2f Hz", model.alphaWave), tint: QAITokens.Palette.cardElevated)
            MegaPipelineMetricCard(title: "Gama Frekansı", value: String(format: "%.2f Hz", model.gammaWave), tint: QAITokens.Palette.chipTeal)
            MegaPipelineMetricCard(title: "Varis Senkron", value: "\(Int(model.heirSyncLevel * 100))%", tint: QAITokens.Palette.chipBlue)
        }
    }
}

private struct MegaPipelineCognitiveCard: View {
    @ObservedObject var model: MegaPipelineMasterModel

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                Text("Bilişsel Köklenme")
                    .font(QAITokens.Typography.cardTitle)
                    .foregroundStyle(QAITokens.Palette.textPrimary)

                Text("Aktif modül: \(model.currentTransferModule)")
                    .font(QAITokens.Typography.body)
                    .foregroundStyle(QAITokens.Palette.textSecondary)

                ProgressView(value: model.heirMaturityIndex)
                    .tint(QAITokens.Palette.gold)

                Text("Olgunlaşma Endeksi %\(Int(model.heirMaturityIndex * 100))")
                    .font(QAITokens.Typography.caption)
                    .foregroundStyle(QAITokens.Palette.textSecondary)
            }
        }
    }
}

private struct MegaPipelineNeuralCard: View {
    @ObservedObject var model: MegaPipelineMasterModel
    let telemetry: [String]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                Text("Telepatik Katman")
                    .font(QAITokens.Typography.cardTitle)
                    .foregroundStyle(QAITokens.Palette.textPrimary)

                Text("Nöral override sinyali telemetry hattına düşer, sonra swarm orkestratör bunu yürütme durumuna geçirir.")
                    .font(QAITokens.Typography.body)
                    .foregroundStyle(QAITokens.Palette.textSecondary)
                    .lineLimit(nil)

                PrimaryActionButton(title: "Zihinsel Taarruz", action: model.issueNeuralOverride)

                VStack(alignment: .leading, spacing: QAITokens.Spacing.xs) {
                    ForEach(telemetry, id: \.self) { entry in
                        Text(entry)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(QAITokens.Palette.textSecondary)
                            .lineLimit(2)
                    }
                }
            }
        }
    }
}

private struct MegaPipelineAgentsCard: View {
    let agents: [MegaPipelineAgentSnapshot]
    private let columns = [GridItem(.adaptive(minimum: 160), spacing: QAITokens.Spacing.s)]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                Text("Ajan Sürüsü")
                    .font(QAITokens.Typography.cardTitle)
                    .foregroundStyle(QAITokens.Palette.textPrimary)

                LazyVGrid(columns: columns, spacing: QAITokens.Spacing.s) {
                    ForEach(agents) { agent in
                        VStack(alignment: .leading, spacing: QAITokens.Spacing.s) {
                            Image(systemName: agent.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(QAITokens.Palette.textPrimary)
                                .frame(width: 38, height: 38)
                                .background(agent.status.tint)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            Text(agent.name)
                                .font(QAITokens.Typography.bodyStrong)
                                .foregroundStyle(QAITokens.Palette.textPrimary)

                            Text(agent.role)
                                .font(QAITokens.Typography.caption)
                                .foregroundStyle(QAITokens.Palette.textSecondary)
                                .lineLimit(2)

                            Text(agent.status.rawValue)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(QAITokens.Palette.textPrimary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(agent.status.tint)
                                .clipShape(Capsule())
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(QAITokens.Spacing.m)
                        .background(Color.white.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                }
            }
        }
    }
}

private struct MegaPipelineMetricCard: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: QAITokens.Spacing.xs) {
                Text(title)
                    .font(QAITokens.Typography.caption)
                    .foregroundStyle(QAITokens.Palette.textSecondary)
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(QAITokens.Palette.textPrimary)
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(tint)
                    .frame(height: 4)
            }
        }
    }
}

private struct MegaPipelinePill: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(QAITokens.Typography.caption)
                .foregroundStyle(QAITokens.Palette.textSecondary)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(QAITokens.Palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(QAITokens.Spacing.s)
        .background(tint)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
