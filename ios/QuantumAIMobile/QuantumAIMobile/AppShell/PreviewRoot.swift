import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct PreviewRoot: View {
    @StateObject private var env: AppEnvironment = {
        let environment = AppEnvironment.liveInSim()
        environment.trainingJourney.completeJourney()
        return environment
    }()

    var body: some View {
        RootView()
            .environmentObject(env)
    }
}

@available(iOS 17.0, macOS 14.0, *)
#Preview {
    PreviewRoot()
}
