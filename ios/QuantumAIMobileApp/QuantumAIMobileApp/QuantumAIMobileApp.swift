import SwiftUI
import QuantumAIMobile
#if canImport(UIKit)
import UIKit
#endif

@main
struct QuantumAIMobileApp: App {
    @StateObject private var env = AppEnvironment.liveInSim()
    @State private var hasBootstrapped = false

    init() {
        #if canImport(UIKit)
        if AppEnvironment.LaunchControl.isUITesting {
            UIView.setAnimationsEnabled(false)
        }
        #endif
    }

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
