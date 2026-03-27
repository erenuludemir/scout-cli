import SwiftUI
import QuantumAIMobile

@main
struct QuantumAIMobileHostApp: App {
    @StateObject private var env = AppEnvironment.liveInSim()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(env)
                .task {
                    await env.bootstrap()
                }
        }
    }
}
