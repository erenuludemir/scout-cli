import SwiftUI

public struct AppShell: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: ShellTab = .panel
    @State private var showTraining = false
    @State private var hasEvaluatedTrainingPresentation = false
    private let launchArguments = ProcessInfo.processInfo.arguments

    public init() {}

    public var body: some View {
        ZStack {
            AppBackground()

            NavigationStack {
                currentScreen
            }
        }
        .preferredColorScheme(.dark)
        .safeAreaInset(edge: .bottom) {
            BottomTabBar(selectedTab: $selectedTab)
                .padding(.horizontal, QAITokens.Layout.tabBarOuterPadding)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .background(Color.clear)
        }
        .task {
            guard !hasEvaluatedTrainingPresentation else { return }
            hasEvaluatedTrainingPresentation = true
            showTraining = !launchArguments.contains("-disable-training-on-launch") && env.trainingJourney.shouldPresentOnLaunch
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }

            // Runtime refresh stays at shell level so every feature inherits the same behavior.
            env.applyRuntimeSettings()
            env.market.refreshForActiveScene()

            if env.settings.marketBridgeEnabled {
                Task {
                    await Task.yield()
                    await env.marketBridge.refreshNow()
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
        case .panel:
            PanelView()
        case .markets:
            MarketBridgeView()
        case .wallet:
            WalletView()
        case .bots:
            TradeView()
        case .settings:
            SettingsView()
        }
    }
}

#Preview {
    AppShell()
        .environmentObject(AppEnvironment.liveInSim())
}
