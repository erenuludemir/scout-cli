import SwiftUI

public struct RootView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: AppTab = .dashboard
    @State private var showTraining = false
    @State private var hasEvaluatedTrainingPresentation = false

    public init() {}

    public var body: some View {
        ZStack {
            QAITheme.shellGradient
                .ignoresSafeArea()
            QAITheme.shellOverlay
                .ignoresSafeArea()

            NavigationStack {
                currentScreen
            }
            .id(selectedTab)
        }
        .preferredColorScheme(.dark)
        .safeAreaInset(edge: .bottom) {
            QuantumTabBar(selectedTab: $selectedTab)
                .padding(.horizontal, QAITheme.shellHorizontalPadding)
                .padding(.top, 6)
                .padding(.bottom, 8)
                .background(Color.clear)
        }
        .task {
            guard !hasEvaluatedTrainingPresentation else { return }
            hasEvaluatedTrainingPresentation = true
            showTraining = env.trainingJourney.shouldPresentOnLaunch
        }
        .onChange(of: scenePhase) { _, phase in
            DispatchQueue.main.async {
                if phase == .active {
                    env.applyRuntimeSettings()
                    env.market.refreshForActiveScene()
                    env.marketBridge.refreshForActiveScene()
                    if env.settings.marketBridgeEnabled {
                        Task {
                            await Task.yield()
                            await env.marketBridge.refreshNow()
                        }
                    }
                } else {
                    env.market.pauseForInactiveScene()
                    env.marketBridge.pauseForInactiveScene()
                }
            }
        }
        #if os(macOS)
        .sheet(isPresented: $showTraining) {
            NavigationStack {
                TrainingJourneyView(showsCloseButton: true)
                    .environmentObject(env)
            }
        }
        #else
        .fullScreenCover(isPresented: $showTraining) {
            NavigationStack {
                TrainingJourneyView(showsCloseButton: true)
                    .environmentObject(env)
            }
        }
        #endif
    }

    @ViewBuilder
    private var currentScreen: some View {
        switch selectedTab {
        case .dashboard:
            DashboardView()
        case .simulations:
            SimulationsHubView()
        case .wallet:
            WalletView()
        case .trade:
            TradeView()
        case .settings:
            SettingsView()
        }
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case dashboard
    case simulations
    case wallet
    case trade
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard:
            return "Panel"
        case .simulations:
            return "Sürüm"
        case .wallet:
            return "Cüzdan"
        case .trade:
            return "Botlar"
        case .settings:
            return "Ayarlar"
        }
    }

    var icon: String {
        switch self {
        case .dashboard:
            return "speedometer"
        case .simulations:
            return "square.stack.3d.up"
        case .wallet:
            return "lock.shield"
        case .trade:
            return "gearshape.2"
        case .settings:
            return "slider.horizontal.3"
        }
    }
}

private struct QuantumTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: 8) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 17, weight: .semibold))
                        Text(tab.title)
                            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(selectedTab == tab ? QAITheme.background : QAITheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        Group {
                            if selectedTab == tab {
                                LinearGradient(
                                    colors: [QAITheme.accent, QAITheme.accent.opacity(0.78)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            } else {
                                LinearGradient(
                                    colors: [QAITheme.surfaceElevated, QAITheme.surface],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            }
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: QAITheme.compactCornerRadius, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(7)
        .background(QAITheme.surface.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(QAITheme.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.24), radius: 20, x: 0, y: 10)
    }
}
