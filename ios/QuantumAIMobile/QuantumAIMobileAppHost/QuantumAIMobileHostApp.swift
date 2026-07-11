#if canImport(QuantumAIMobile)
import QuantumAIMobile
#endif
import SwiftUI

@main
struct QuantumAIMobileHostApp: App {
#if canImport(QuantumAIMobile)
    @StateObject private var env = AppEnvironment.liveInSim()
    @State private var hasBootstrapped = false
#endif

    var body: some Scene {
        WindowGroup {
#if canImport(QuantumAIMobile)
            AppShell()
            .environmentObject(env)
            .task {
                guard !hasBootstrapped else { return }
                hasBootstrapped = true
                await Task.yield()
                await env.bootstrap()
            }
#else
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                    .font(.system(size: 48))
                Text("Missing package product 'QuantumAIMobile'")
                    .font(.headline)
                Text("Add the Swift package to the project or workspace to use the real host root view.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
#endif
        }
    }
}
