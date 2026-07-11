import SwiftUI
import Combine

public struct HQAdminView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    @ObservedObject private var sinir = GlobalSinirSistemi.paylasilan
    @ObservedObject private var wealthBridge = WealthBridge.shared
    @ObservedObject private var simulations = SimulationControlCenter.shared
    @ObservedObject private var quantumEngine = QuantumCryptoEngine.shared
    @ObservedObject private var twin = CognitiveTwinRegistry.shared
    @ObservedObject private var citadel = BarakfakihCitadel.shared
    @ObservedObject private var telepathy = TelepathyGateway.shared
    @ObservedObject private var autonomy = AutonomyControlCenter.shared
    @ObservedObject private var neuroVisor = NeuroVisorEngine.shared

    @StateObject private var viewModel = HQAdminViewModel()

    private let showsBackButton: Bool

    public init(showsBackButton: Bool = false) {
        self.showsBackButton = showsBackButton
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: QAITokens.Spacing.l) {
                ScreenHeader(
                    title: "HQ Admin",
                    showsBackButton: showsBackButton,
                    onBack: { dismiss() }
                )

                HQGlobalControlCard(
                    globalState: viewModel.globalState,
                    buildText: viewModel.buildText,
                    modeText: viewModel.modeText,
                    lastSyncText: viewModel.lastSyncText,
                    commandState: viewModel.commandState,
                    lastCommandText: viewModel.lastCommandText,
                    lastSuccessText: viewModel.lastSuccessText,
                    lastFailureText: viewModel.lastFailureText,
                    recoveryAction: { viewModel.selectedSegment = .recovery },
                    onAction: { action in
                        viewModel.runGlobalAction(action, env: env)
                    }
                )

                HQSystemHealthMonitor(
                    items: viewModel.quickMonitors,
                    tags: viewModel.healthTags
                )

                segmentContent
            }
            .padding(.horizontal, QAITokens.Layout.screenPadding)
            .padding(.top, QAITokens.Spacing.s)
            .padding(.bottom, QAITokens.Layout.dockedBottomClearance + 88)
        }
        .accessibilityIdentifier("hq-admin-screen")
        .background(AppBackground())
        .screenNavigationChromeHidden()
        .overlay(alignment: .top) {
            if let banner = viewModel.banner {
                HQCommandExecutionBanner(banner: banner)
                    .padding(.top, 8)
                    .padding(.horizontal, QAITokens.Layout.screenPadding)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HQSegmentDock(selectedSegment: $viewModel.selectedSegment)
                .padding(.horizontal, QAITokens.Layout.screenPadding)
                .padding(.bottom, 74)
        }
        .sheet(item: $viewModel.dangerRequest) { request in
            HQDangerZoneSheet(
                request: request,
                cancelAction: { viewModel.cancelDangerAction() },
                confirmAction: { viewModel.confirmDangerAction(env: env) }
            )
        }
        .task {
            quantumEngine.bindTrainingJourney(env.trainingJourney)
            viewModel.refresh(with: env)
        }
        .onReceive(refreshPublisher) { _ in
            viewModel.refresh(with: env)
        }
    }

    @ViewBuilder
    private var segmentContent: some View {
        switch viewModel.selectedSegment {
        case .commands:
            LazyVGrid(columns: moduleColumns, spacing: QAITokens.Spacing.m) {
                ForEach(viewModel.modules) { item in
                    HQModuleControlCard(item: item) { action in
                        viewModel.runModuleAction(action, module: item.id, env: env)
                    }
                }
            }

        case .recovery:
            HQRecoveryPanel(
                actions: viewModel.recoveryActions,
                commandState: viewModel.commandState,
                lastCommandText: viewModel.lastCommandText
            ) { action in
                viewModel.runRecoveryAction(action, env: env)
            }

        case .logs:
            VStack(spacing: QAITokens.Spacing.m) {
                HQOperationTimelineCard(
                    items: viewModel.operationTimeline,
                    filters: viewModel.timelineFilters,
                    selectedFilter: $viewModel.timelineFilter
                )

                HQEventStreamPanel(
                    events: viewModel.events,
                    lastCommandText: viewModel.lastCommandText,
                    exportAction: { viewModel.runRecoveryAction(.telemetryExport, env: env) }
                )
            }

        case .security:
            HQInspectorCard(
                title: "Security Monitor",
                icon: "shield.lefthalf.filled",
                metrics: viewModel.securityMonitors,
                footer: viewModel.securityFooter
            )

        case .runtime:
            VStack(spacing: QAITokens.Spacing.m) {
                HQInspectorCard(
                    title: "Runtime Monitor",
                    icon: "cpu.fill",
                    metrics: viewModel.runtimeMonitors,
                    footer: viewModel.runtimeFooter
                )

                HQRuntimeOperationsCard(
                    lanes: viewModel.runtimeTrendLanes,
                    topics: viewModel.runtimeTopics,
                    replayAction: { viewModel.runRecoveryAction(.retryTrim, env: env) },
                    logsAction: {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                            viewModel.selectedSegment = .logs
                        }
                    }
                )

                HQOperationTimelineCard(
                    items: viewModel.operationTimeline,
                    filters: viewModel.timelineFilters,
                    selectedFilter: $viewModel.timelineFilter
                )
            }
        }
    }

    private var moduleColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 320, maximum: 520), spacing: QAITokens.Spacing.m)]
    }

    private var refreshPublisher: AnyPublisher<Void, Never> {
        Publishers.MergeMany(
            env.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            sinir.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            wealthBridge.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            simulations.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            quantumEngine.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            twin.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            citadel.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            telepathy.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            autonomy.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            neuroVisor.objectWillChange.map { _ in () }.eraseToAnyPublisher()
        )
        .eraseToAnyPublisher()
    }
}

private struct HQSegmentDock: View {
    @Binding var selectedSegment: HQAdminSegment

    var body: some View {
        HStack(spacing: QAITokens.Spacing.xs) {
            ForEach(HQAdminSegment.allCases) { segment in
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        selectedSegment = segment
                    }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: segment.systemImage)
                            .font(.system(size: 15, weight: .semibold))
                        Text(segment.title)
                            .font(QAITokens.Typography.tab)
                    }
                    .foregroundStyle(
                        selectedSegment == segment
                        ? QAITokens.Palette.backgroundBottom
                        : QAITokens.Palette.textPrimary
                    )
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 54)
                    .background(
                        selectedSegment == segment
                        ? QAITokens.Palette.gold
                        : QAITokens.Palette.cardElevated
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(QAITokens.Palette.card.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: QAITokens.Radius.tab, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: QAITokens.Radius.tab, style: .continuous)
                .stroke(QAITokens.Palette.stroke, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.24), radius: 18, x: 0, y: 10)
    }
}

private struct HQInspectorCard: View {
    let title: String
    let icon: String
    let metrics: [HQQuickMonitor]
    let footer: String

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                Label(title, systemImage: icon)
                    .font(QAITokens.Typography.cardTitle)
                    .foregroundStyle(QAITokens.Palette.textPrimary)

                LazyVGrid(columns: columns, spacing: QAITokens.Spacing.s) {
                    ForEach(metrics) { metric in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(metric.title)
                                .font(QAITokens.Typography.caption)
                                .foregroundStyle(QAITokens.Palette.textSecondary)
                            Text(metric.value)
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundStyle(QAITokens.Palette.textPrimary)
                            if let detail = metric.detail {
                                Text(detail)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(QAITokens.Palette.textSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(QAITokens.Spacing.s)
                        .background(metric.tint)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }

                Text(footer)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(QAITokens.Palette.textSecondary)
                    .lineLimit(nil)
            }
        }
    }

    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: QAITokens.Spacing.s),
            GridItem(.flexible(), spacing: QAITokens.Spacing.s)
        ]
    }
}

#Preview {
    NavigationStack {
        HQAdminView(showsBackButton: true)
            .environmentObject(AppEnvironment.liveInSim())
    }
}
