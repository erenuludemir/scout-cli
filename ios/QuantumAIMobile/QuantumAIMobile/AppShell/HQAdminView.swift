import SwiftUI

public struct HQAdminView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var sinir = GlobalSinirSistemi.paylasilan
    @ObservedObject private var wealthBridge = WealthBridge.shared
    @ObservedObject private var simulations = SimulationControlCenter.shared
    @ObservedObject private var branding = PartnerBrandingEngine.shared
    @ObservedObject private var quantumEngine = QuantumCryptoEngine.shared
    @ObservedObject private var twin = CognitiveTwinRegistry.shared
    @ObservedObject private var citadel = BarakfakihCitadel.shared
    @ObservedObject private var telepathy = TelepathyGateway.shared
    @ObservedObject private var computation = MegaComputationEngine.shared
    private let showsBackButton: Bool

    public init(showsBackButton: Bool = false) {
        self.showsBackButton = showsBackButton
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: QAITokens.Spacing.l) {
                ScreenHeader(title: "Bursa HQ Enterprise", showsBackButton: showsBackButton, onBack: { dismiss() })

                enterpriseHeroCard
                commandRailCard
                hierarchyCard
                autonomyOverlayCard
                moduleCatalogCard
                BursaHQTerminalView(bindToMetrics: true)
            }
            .padding(.horizontal, QAITokens.Layout.screenPadding)
            .padding(.top, QAITokens.Spacing.s)
            .padding(.bottom, QAITokens.Layout.dockedBottomClearance)
        }
        .accessibilityIdentifier("hq-admin-screen")
        .background(AppBackground())
        .screenNavigationChromeHidden()
        .task {
            quantumEngine.bindTrainingJourney(env.trainingJourney)
        }
    }

    private var enterpriseHeroCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                Text(branding.currentPartnerName)
                    .font(QAITokens.Typography.largeTitle)
                    .foregroundStyle(QAITokens.Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                VStack(alignment: .leading, spacing: 6) {
                    Text("BURSA HQ TOTAL EQUITY")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(QAITokens.Palette.textSecondary)
                    Text("$52400150.00")
                        .font(.system(size: 34, weight: .black, design: .monospaced))
                        .foregroundStyle(QAITokens.Palette.gold)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(QAITokens.Spacing.m)
                .background(Color(red: 43.0 / 255.0, green: 30.0 / 255.0, blue: 14.0 / 255.0).opacity(0.82))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                VStack(alignment: .leading, spacing: QAITokens.Spacing.s) {
                    Text("AKTIF WHITE-LABEL KANALLARI")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(QAITokens.Palette.textSecondary)

                    HStack(spacing: QAITokens.Spacing.s) {
                        HQPartnerChannelButton(title: "Bursa HQ", tint: QAITokens.Palette.gold, active: branding.currentPartnerName.contains("BURSA")) {
                            branding.applyPartnerTheme(partnerID: "BURSA_HQ")
                        }
                        HQPartnerChannelButton(title: "Bank-X", tint: QAITokens.Palette.chipBlue, active: branding.currentPartnerName.contains("BANK")) {
                            branding.applyPartnerTheme(partnerID: "OSMANGAZI_BANK_X")
                        }
                        HQPartnerChannelButton(title: "Invest-Grp", tint: QAITokens.Palette.chipAmber, active: branding.currentPartnerName.contains("INVEST")) {
                            branding.applyPartnerTheme(partnerID: "BURSA_INVEST_01")
                        }
                    }
                }

                HStack(alignment: .top, spacing: QAITokens.Spacing.s) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(QAITokens.Palette.gold)
                    Text(aiRecommendation)
                        .font(QAITokens.Typography.caption)
                        .foregroundStyle(QAITokens.Palette.textPrimary)
                        .lineLimit(nil)
                }
                .padding(QAITokens.Spacing.m)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                HStack(spacing: QAITokens.Spacing.s) {
                    HQSummaryStat(title: "Modules", value: "\(simulations.totalModuleCount)", tint: QAITokens.Palette.chipBlue)
                    HQSummaryStat(title: "QKD", value: quantumEngine.qkdStatus, tint: QAITokens.Palette.chipTeal)
                    HQSummaryStat(title: "Blocked", value: "\(sinir.blockedIPCount)", tint: QAITokens.Palette.chipAmber)
                }
            }
        }
    }

    private var commandRailCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                Text("HQ Admin / Command")
                    .font(QAITokens.Typography.cardTitle)
                    .foregroundStyle(QAITokens.Palette.textPrimary)

                Text("Gorsellerdeki enterprise ve mega pipeline akislarini mevcut quantum ops hiyerarsisi ile ayni komut yuzeyinde birlestirir.")
                    .font(QAITokens.Typography.body)
                    .foregroundStyle(QAITokens.Palette.textSecondary)
                    .lineLimit(nil)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: QAITokens.Spacing.s), GridItem(.flexible(), spacing: QAITokens.Spacing.s)], spacing: QAITokens.Spacing.s) {
                    NavigationLink {
                        QuantumPerformanceDashboard(showsBackButton: true)
                    } label: {
                        HQCommandRailTile(title: "Quantum Ops", subtitle: quantumEngine.hierarchySnapshot.dispatchMode, icon: "shield.lefthalf.filled", tint: QAITokens.Palette.chipTeal)
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        MegaPipelineView()
                    } label: {
                        HQCommandRailTile(title: "Mega Pipeline", subtitle: String(format: "915 TX/S | p=%.2f%%", computation.lastProbability), icon: "wave.3.right.circle.fill", tint: QAITokens.Palette.chipBlue)
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        PartnerCommandView()
                    } label: {
                        HQCommandRailTile(title: "White-Label", subtitle: branding.currentPartnerName, icon: "building.2.crop.circle", tint: QAITokens.Palette.chipAmber)
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        CommandCenterView()
                    } label: {
                        HQCommandRailTile(title: "Command Center", subtitle: "Dispatch / recovery / dry-run", icon: "command.circle.fill", tint: QAITokens.Palette.cardElevated)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var hierarchyCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                Text("Hierarchy Optimization")
                    .font(QAITokens.Typography.cardTitle)
                    .foregroundStyle(QAITokens.Palette.textPrimary)

                Text(quantumEngine.hierarchySnapshot.headline)
                    .font(QAITokens.Typography.bodyStrong)
                    .foregroundStyle(QAITokens.Palette.textPrimary)
                    .lineLimit(nil)

                Text(quantumEngine.hierarchySnapshot.dispatchMode)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(QAITokens.Palette.gold)
                    .lineLimit(nil)

                VStack(alignment: .leading, spacing: QAITokens.Spacing.s) {
                    HStack(spacing: QAITokens.Spacing.s) {
                        HQSummaryStat(title: "Training", value: "%\(Int(quantumEngine.trainingSnapshot.progressValue * 100))", tint: QAITokens.Palette.chipBlue)
                        HQSummaryStat(title: "Step", value: "\(quantumEngine.trainingSnapshot.currentStep.rawValue + 1)/\(TrainingJourneyStep.allCases.count)", tint: QAITokens.Palette.chipTeal)
                        HQSummaryStat(title: "Modules", value: "\(quantumEngine.trainingSnapshot.selectedModuleTitles.count)", tint: QAITokens.Palette.chipAmber)
                    }

                    ProgressView(value: quantumEngine.trainingSnapshot.progressValue)
                        .tint(QAITokens.Palette.gold)

                    Text(quantumEngine.trainingSnapshot.currentStepTitle)
                        .font(QAITokens.Typography.bodyStrong)
                        .foregroundStyle(QAITokens.Palette.textPrimary)

                    if let blockingReason = quantumEngine.trainingSnapshot.blockingReason {
                        Text(blockingReason)
                            .font(QAITokens.Typography.caption)
                            .foregroundStyle(QAITokens.Palette.warning)
                            .lineLimit(nil)
                    } else {
                        Text("Training sync aktif. Quantum hierarchy kararları artık gerçek journey adımı ve ilerleme yüzdesi ile ağırlıklandırılıyor.")
                            .font(QAITokens.Typography.caption)
                            .foregroundStyle(QAITokens.Palette.textSecondary)
                            .lineLimit(nil)
                    }
                }

                ForEach(quantumEngine.hierarchySnapshot.priorities) { priority in
                    HStack(alignment: .top, spacing: QAITokens.Spacing.s) {
                        Text(priorityBadge(priority.level))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(QAITokens.Palette.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(priorityTint(priority.level))
                            .clipShape(Capsule())

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

    private var autonomyOverlayCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                Text("New Autonomy Overlays")
                    .font(QAITokens.Typography.cardTitle)
                    .foregroundStyle(QAITokens.Palette.textPrimary)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: QAITokens.Spacing.s), GridItem(.flexible(), spacing: QAITokens.Spacing.s)], spacing: QAITokens.Spacing.s) {
                    NavigationLink {
                        DigitalTwinView(showsBackButton: true)
                    } label: {
                        HQOverlayTile(title: "Digital Twin", subtitle: twin.statusText, value: "%\(Int(twin.syncProgress * 100))", icon: "brain", tint: QAITokens.Palette.chipBlue)
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        CitadelStatusView(showsBackButton: true)
                    } label: {
                        HQOverlayTile(title: "Smart Citadel", subtitle: citadel.uplinkStatus, value: citadel.isSealed ? "Locked" : "Standby", icon: "building.columns.circle", tint: QAITokens.Palette.chipAmber)
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        NeuralCommandView(showsBackButton: true)
                    } label: {
                        HQOverlayTile(title: "Neural Command", subtitle: telepathy.lastIntentCode, value: String(format: "%.3f ms", telepathy.lastLatencyMs), icon: "brain.head.profile", tint: QAITokens.Palette.chipTeal)
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        EternityView(showsBackButton: true)
                    } label: {
                        HQOverlayTile(title: "Eternity Relay", subtitle: "Twin + Citadel + Rail", value: "HOT", icon: "flame.fill", tint: QAITokens.Palette.cardElevated)
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: QAITokens.Spacing.s) {
                    SecondaryCommandButton(title: "Mentor Sync") {
                        twin.mentorHeir(currentHeirAgeMonths: 54)
                    }
                    SecondaryCommandButton(title: "Seal Citadel") {
                        citadel.fortifyPhysicalAnchor()
                    }
                    SecondaryCommandButton(title: "Pulse Intent") {
                        telepathy.processBrainwaveCommand(intentCode: "INTENT_QKD_MONITOR")
                    }
                }
            }
        }
    }

    private var moduleCatalogCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                Text("Compiled Runtime Modules (\(SimulationCatalog.totalModuleCount))")
                    .font(QAITokens.Typography.cardTitle)
                    .foregroundStyle(QAITokens.Palette.textPrimary)

                Text("32 mevcut runtime modulu geri getirildi. Yeni otonomi overlay'leri command rail uzerinde ayrica baglandi; boylece mevcut katalog korunurken komut akisina yeni katmanlar eklendi.")
                    .font(QAITokens.Typography.body)
                    .foregroundStyle(QAITokens.Palette.textSecondary)
                    .lineLimit(nil)

                ForEach(SimulationCatalog.all) { bundle in
                    VStack(alignment: .leading, spacing: QAITokens.Spacing.s) {
                        HStack {
                            Label(bundle.version.displayName, systemImage: bundle.version.icon)
                                .font(QAITokens.Typography.bodyStrong)
                                .foregroundStyle(QAITokens.Palette.textPrimary)
                            Spacer()
                            Text("\(bundle.compiledModuleCount) mod")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(bundle.version.accent)
                        }

                        Text(bundle.overview)
                            .font(QAITokens.Typography.caption)
                            .foregroundStyle(QAITokens.Palette.textSecondary)
                            .lineLimit(nil)

                        ForEach(bundle.modules) { module in
                            NavigationLink {
                                HQModuleDetailView(module: module)
                            } label: {
                                HQModuleRow(module: module)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(QAITokens.Spacing.m)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
            }
        }
    }

    private var aiRecommendation: String {
        if let first = quantumEngine.hierarchySnapshot.priorities.first {
            return "AI onerisi: \(first.title.lowercased()) | rota: \(first.route)."
        }
        if wealthBridge.statusText == "TETIKLENDI" {
            return "AI onerisi: gayrimenkul / nakit orani dengeli. Wealth bridge son transfer kaydini tuttu."
        }
        return "AI onerisi: gayrimenkul / nakit orani dengeli. Komut rayi stabil durumda."
    }

    private func priorityBadge(_ level: QuantumProjectPriorityLevel) -> String {
        switch level {
        case .critical: return "CRITICAL"
        case .high: return "HIGH"
        case .medium: return "MEDIUM"
        case .low: return "LOW"
        }
    }

    private func priorityTint(_ level: QuantumProjectPriorityLevel) -> Color {
        switch level {
        case .critical: return Color.red.opacity(0.85)
        case .high: return QAITokens.Palette.warning
        case .medium: return QAITokens.Palette.chipBlue
        case .low: return QAITokens.Palette.chipTeal
        }
    }
}

private struct HQPartnerChannelButton: View {
    let title: String
    let tint: Color
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: "building.2.fill")
                    .font(.system(size: 22, weight: .semibold))
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(QAITokens.Palette.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 92)
            .background(tint.opacity(active ? 0.38 : 0.14))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(tint.opacity(active ? 1.0 : 0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct HQSummaryStat: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(QAITokens.Typography.caption)
                .foregroundStyle(QAITokens.Palette.textSecondary)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(QAITokens.Palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(QAITokens.Spacing.s)
        .background(tint)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct HQCommandRailTile: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: QAITokens.Spacing.s) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(QAITokens.Palette.textPrimary)
            Text(title)
                .font(QAITokens.Typography.bodyStrong)
                .foregroundStyle(QAITokens.Palette.textPrimary)
            Text(subtitle)
                .font(QAITokens.Typography.caption)
                .foregroundStyle(QAITokens.Palette.textSecondary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
        .padding(QAITokens.Spacing.m)
        .background(tint)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct HQOverlayTile: View {
    let title: String
    let subtitle: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: QAITokens.Spacing.s) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(QAITokens.Palette.textPrimary)
                Spacer()
                Text(value)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(QAITokens.Palette.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.18))
                    .clipShape(Capsule())
            }

            Text(title)
                .font(QAITokens.Typography.bodyStrong)
                .foregroundStyle(QAITokens.Palette.textPrimary)
            Text(subtitle)
                .font(QAITokens.Typography.caption)
                .foregroundStyle(QAITokens.Palette.textSecondary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
        .padding(QAITokens.Spacing.m)
        .background(tint)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct SecondaryCommandButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(QAITokens.Palette.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(QAITokens.Palette.cardElevated)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct HQModuleRow: View {
    let module: SimulationModule

    var body: some View {
        HStack(alignment: .top, spacing: QAITokens.Spacing.s) {
            VStack(alignment: .leading, spacing: 6) {
                Text(module.title)
                    .font(QAITokens.Typography.bodyStrong)
                    .foregroundStyle(QAITokens.Palette.textPrimary)
                Text(module.summary)
                    .font(QAITokens.Typography.caption)
                    .foregroundStyle(QAITokens.Palette.textSecondary)
                    .lineLimit(3)
                Text(module.integrationMode.title)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(module.version.accent)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(QAITokens.Palette.textSecondary)
        }
        .padding(QAITokens.Spacing.s)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct HQModuleDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let module: SimulationModule

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: QAITokens.Spacing.l) {
                ScreenHeader(title: module.title, showsBackButton: true, onBack: { dismiss() })

                GlassCard {
                    VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                        HStack {
                            Label(module.version.displayName, systemImage: module.version.icon)
                                .font(QAITokens.Typography.bodyStrong)
                                .foregroundStyle(QAITokens.Palette.textPrimary)
                            Spacer()
                            Text(module.integrationMode.title)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(module.version.accent)
                        }

                        Text(module.summary)
                            .font(QAITokens.Typography.body)
                            .foregroundStyle(QAITokens.Palette.textSecondary)
                            .lineLimit(nil)

                        Text(module.originHint)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(QAITokens.Palette.gold)
                            .lineLimit(nil)

                        Text(module.integrationMode.detail)
                            .font(QAITokens.Typography.caption)
                            .foregroundStyle(QAITokens.Palette.textSecondary)
                            .lineLimit(nil)
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                        Text("Capabilities")
                            .font(QAITokens.Typography.cardTitle)
                            .foregroundStyle(QAITokens.Palette.textPrimary)

                        ForEach(module.capabilities, id: \.self) { capability in
                            Text(capability)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(QAITokens.Palette.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(module.version.accent.opacity(0.24))
                                .clipShape(Capsule())
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                if hasLiveSurface {
                    GlassCard {
                        VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                            Text("Live Surface")
                                .font(QAITokens.Typography.cardTitle)
                                .foregroundStyle(QAITokens.Palette.textPrimary)
                            NavigationLink {
                                liveSurface
                            } label: {
                                HStack {
                                    Text("Open live surface")
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
            .padding(.horizontal, QAITokens.Layout.screenPadding)
            .padding(.top, QAITokens.Spacing.s)
            .padding(.bottom, QAITokens.Layout.dockedBottomClearance)
        }
        .background(AppBackground())
        .screenNavigationChromeHidden()
    }

    private var hasLiveSurface: Bool {
        switch module.slug {
        case "mega-pipeline", "saas-layer", "quantum-agent", "sovereign-command", "command", "physical-anchor", "legacy", "ghost", "qkd", "property-genesis":
            return true
        default:
            return false
        }
    }

    @ViewBuilder
    private var liveSurface: some View {
        switch module.slug {
        case "mega-pipeline":
            MegaPipelineView()
        case "saas-layer":
            PartnerCommandView()
        case "quantum-agent", "qkd":
            QuantumPerformanceDashboard(showsBackButton: true)
        case "sovereign-command":
            CommandCenterView()
        case "command":
            NeuralCommandView(showsBackButton: true)
        case "physical-anchor":
            CitadelStatusView(showsBackButton: true)
        case "legacy":
            DigitalTwinView(showsBackButton: true)
        case "ghost":
            EternityView(showsBackButton: true)
        case "property-genesis":
            PropertyIgnitionView()
        default:
            EmptyView()
        }
    }
}
