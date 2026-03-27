import SwiftUI

#if !SWIFT_PACKAGE
@main
struct QuantumAIMobileApp: App {
    @StateObject private var env = AppEnvironment.liveInSim()

    var body: some Scene {
        WindowGroup {
            AppShell()
                .environmentObject(env)
                .task {
                    await env.bootstrap()
                }
        }
    }
}
#endif
