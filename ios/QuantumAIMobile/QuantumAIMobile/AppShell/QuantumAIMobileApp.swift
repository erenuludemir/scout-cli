import SwiftUI

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
