import SwiftUI
import QuantumAIMobile

struct HostRootView: View {
    @StateObject private var env = AppEnvironment.liveInSim()
    @State private var hasBootstrapped = false

    var body: some View {
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
