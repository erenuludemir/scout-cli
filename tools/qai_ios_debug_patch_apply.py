#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from pathlib import Path
import sys

ROOT = Path("/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3")
APP = ROOT / "ios/QuantumAIMobile/QuantumAIMobile/AppShell/QuantumAIMobileApp.swift"
ROOTVIEW = ROOT / "ios/QuantumAIMobile/QuantumAIMobile/AppShell/RootView.swift"
MARKET_BRIDGE = ROOT / "ios/QuantumAIMobile/QuantumAIMobile/AppShell/MarketBridgeView.swift"
MARKET_DATA = ROOT / "ios/QuantumAIMobile/QuantumAIMobile/MarketKit/MarketDataService.swift"

for p in [APP, ROOTVIEW, MARKET_BRIDGE, MARKET_DATA]:
    if not p.exists():
        print(f"EKSIK_DOSYA:{p}")
        sys.exit(2)

app_text = """import SwiftUI

#if !SWIFT_PACKAGE
@main
struct QuantumAIMobileApp: App {
    @StateObject private var env = AppEnvironment.liveInSim()
    @State private var hasBootstrapped = false

    var body: some Scene {
        WindowGroup {
            AppShell()
                .environmentObject(env)
                .task {
                    guard !hasBootstrapped else { return }
                    hasBootstrapped = true
                    await Task.yield()
                    await env.bootstrap()
                }
        }
    }
}
#endif
"""

root_view_text = """import SwiftUI

public struct RootView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\\.scenePhase) private var scenePhase
    @State private var selectedTab: AppTab = .dashboard
    @State private var showTraining = false
    @State private var hasEvaluatedTrainingPresentation = false
    @State private var sceneRefreshTask: Task<Void, Never>?

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
            sceneRefreshTask?.cancel()
            if phase == .active {
                sceneRefreshTask = Task {
                    await Task.yield()
                    guard !Task.isCancelled else { return }
                    env.applyRuntimeSettings()
                    env.market.refreshForActiveScene()
                    env.marketBridge.refreshForActiveScene()
                    env.walletPortfolio.refreshForActiveScene()
                }
            } else {
                env.market.pauseForInactiveScene()
                env.marketBridge.pauseForInactiveScene()
                env.walletPortfolio.pauseForInactiveScene()
            }
        }
        .onDisappear {
            sceneRefreshTask?.cancel()
            sceneRefreshTask = nil
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
"""

def patch_market_bridge(text: str) -> str:
    text = text.replace(
        '@State private var selectedSection: BridgeSection = .snapshot\n',
        '@State private var selectedSection: BridgeSection = .snapshot\n    @State private var hasPreparedRuntime = false\n    @State private var settingsRefreshTask: Task<Void, Never>?\n'
    )
    old = """        .task {
            env.training.loadIfNeeded()
            env.applyRuntimeSettings()
        }
        .onChange(of: env.settings.selectedSymbol) { _, symbol in
            guard env.settings.marketBridgeEnabled, !symbol.isEmpty else { return }
            env.applyRuntimeSettings()
        }
        .onChange(of: env.settings.marketBridgeEnabled) { _, isEnabled in
            _ = isEnabled
            env.applyRuntimeSettings()
        }
"""
    new = """        .task {
            guard !hasPreparedRuntime else { return }
            hasPreparedRuntime = true
            await Task.yield()
            if env.settings.marketBridgeEnabled {
                env.applyRuntimeSettings()
            }
        }
        .onChange(of: selectedSection) { _, section in
            guard section == .guide else { return }
            env.training.loadIfNeeded()
        }
        .onChange(of: env.settings.selectedSymbol) { _, symbol in
            guard env.settings.marketBridgeEnabled, !symbol.isEmpty else { return }
            settingsRefreshTask?.cancel()
            settingsRefreshTask = Task {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                env.applyRuntimeSettings()
            }
        }
        .onChange(of: env.settings.marketBridgeEnabled) { _, isEnabled in
            settingsRefreshTask?.cancel()
            guard isEnabled else { return }
            settingsRefreshTask = Task {
                await Task.yield()
                guard !Task.isCancelled else { return }
                env.applyRuntimeSettings()
            }
        }
        .onDisappear {
            settingsRefreshTask?.cancel()
            settingsRefreshTask = nil
        }
"""
    if old not in text:
        raise RuntimeError("MarketBridgeView task/onChange bloğu bulunamadı")
    return text.replace(old, new, 1)

def patch_market_data(text: str) -> str:
    if 'private var liveWarmupTask: Task<Void, Never>?' not in text:
        text = text.replace(
            '    private var liveReconnectTask: Task<Void, Never>?\n',
            '    private var liveReconnectTask: Task<Void, Never>?\n    private var liveWarmupTask: Task<Void, Never>?\n',
            1
        )

    text = text.replace(
        """        liveReconnectTask?.cancel()
        liveReconnectTask = nil

        liveFallbackTask?.cancel()
        liveFallbackTask = nil
""",
        """        liveReconnectTask?.cancel()
        liveReconnectTask = nil

        liveWarmupTask?.cancel()
        liveWarmupTask = nil

        liveFallbackTask?.cancel()
        liveFallbackTask = nil
""",
        1
    )

    text = text.replace(
        """        liveReconnectTask?.cancel()
        liveReconnectTask = nil

        binanceAdapter?.disconnect()
        binanceAdapter = nil
        activeLiveConnectionID = nil

        startFallbackWatchdog(symbol: symbol)
        refreshFallbackIfNeeded(symbol: symbol, reason: "Canlı akış bağlanıyor.")
""",
        """        liveReconnectTask?.cancel()
        liveReconnectTask = nil

        liveWarmupTask?.cancel()
        liveWarmupTask = nil

        binanceAdapter?.disconnect()
        binanceAdapter = nil
        activeLiveConnectionID = nil
""",
        1
    )

    text = text.replace(
        """        binanceAdapter = adapter
        adapter.connect()
        liveState = .live(symbol: symbol)
    }
""",
        """        binanceAdapter = adapter
        adapter.connect()
        liveState = .live(symbol: symbol)

        scheduleInitialFallbackProbe(symbol: symbol)
        startFallbackWatchdog(symbol: symbol)
    }
""",
        1
    )

    text = text.replace(
        """        liveReconnectTask?.cancel()
        liveReconnectTask = nil

        binanceAdapter?.disconnect()
""",
        """        liveReconnectTask?.cancel()
        liveReconnectTask = nil

        liveWarmupTask?.cancel()
        liveWarmupTask = nil

        binanceAdapter?.disconnect()
""",
        1
    )

    text = text.replace(
        """        liveReconnectTask?.cancel()
        liveReconnectTask = nil

        if !currentModeIsSim {
""",
        """        liveReconnectTask?.cancel()
        liveReconnectTask = nil
        liveWarmupTask?.cancel()
        liveWarmupTask = nil

        if !currentModeIsSim {
""",
        1
    )

    text = text.replace(
        """        liveReconnectTask?.cancel()
        binanceAdapter?.disconnect()
""",
        """        liveReconnectTask?.cancel()
        liveWarmupTask?.cancel()
        binanceAdapter?.disconnect()
""",
        1
    )

    text = text.replace(
        """        let now = Date()
        lastWebSocketTickAt = tick.ts
""",
        """        let now = Date()
        liveWarmupTask?.cancel()
        liveWarmupTask = nil
        lastWebSocketTickAt = tick.ts
""",
        1
    )

    text = text.replace(
        """        websocketFailureCount += 1
        let reconnectDelay = reconnectDelayForCurrentState()

        binanceAdapter?.disconnect()
""",
        """        websocketFailureCount += 1
        let reconnectDelay = reconnectDelayForCurrentState()

        liveWarmupTask?.cancel()
        liveWarmupTask = nil

        binanceAdapter?.disconnect()
""",
        1
    )

    if "private func scheduleInitialFallbackProbe(symbol: String)" not in text:
        marker = "    private func startFallbackWatchdog(symbol: String) {"
        insert = """    private func scheduleInitialFallbackProbe(symbol: String) {
        guard isSceneActive else { return }

        liveWarmupTask?.cancel()
        liveWarmupTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            guard let self else { return }

            let shouldProbe = await MainActor.run {
                guard self.started, !self.currentModeIsSim, self.currentSymbol == symbol, self.isSceneActive else { return false }
                return self.lastWebSocketTickAt == nil
            }

            guard shouldProbe else { return }
            await self.refreshFallbackTick(symbol: symbol, reason: "Websocket ilk tick gecikti, geçici REST verisi kullanılıyor.")
        }
    }

"""
        if marker not in text:
            raise RuntimeError("MarketDataService startFallbackWatchdog bloğu bulunamadı")
        text = text.replace(marker, insert + marker, 1)

    return text

APP.write_text(app_text, encoding="utf-8")
ROOTVIEW.write_text(root_view_text, encoding="utf-8")
MARKET_BRIDGE.write_text(patch_market_bridge(MARKET_BRIDGE.read_text(encoding="utf-8")), encoding="utf-8")
MARKET_DATA.write_text(patch_market_data(MARKET_DATA.read_text(encoding="utf-8")), encoding="utf-8")

print(f"PATCHED:{APP}")
print(f"PATCHED:{ROOTVIEW}")
print(f"PATCHED:{MARKET_BRIDGE}")
print(f"PATCHED:{MARKET_DATA}")
print("STATUS:OK")
