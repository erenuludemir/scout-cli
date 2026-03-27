import Foundation

@MainActor
public final class NeuroVisorEngine: ObservableObject {
    public static let shared = NeuroVisorEngine()

    @Published public var systemLoad: Double = 0.45
    @Published public var redpandaThroughput: Int = 1250
    @Published public var neuralSynapseHealth: Double = 0.99

    private var timer: Timer?

    private init() {
        startTelemetryPulse()
    }

    private func startTelemetryPulse() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.systemLoad = Double.random(in: 0.30 ... 0.60)
                self.redpandaThroughput = Int.random(in: 1100 ... 1500)
                self.neuralSynapseHealth = Double.random(in: 0.95 ... 0.999)
            }
        }
    }

    deinit {
        timer?.invalidate()
    }
}
