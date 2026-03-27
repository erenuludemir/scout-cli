import Foundation
import SwiftUI

@MainActor
public final class MegaComputationEngine: ObservableObject {
    public static let shared = MegaComputationEngine()

    @Published public private(set) var isRunning = false
    @Published public private(set) var lastProbability: Double = 2.4
    @Published public private(set) var lastIterationCount: Int = 0

    private init() {}

    public func simulateWealthGrowth(iterations: Int = 100_000) {
        guard !isRunning else { return }
        isRunning = true
        lastIterationCount = iterations

        DispatchQueue.global(qos: .userInitiated).async {
            var successCount = 0
            for _ in 0..<iterations {
                if Double.random(in: 0...1) > 0.976 {
                    successCount += 1
                }
            }

            let probability = (Double(successCount) / Double(iterations)) * 100

            Task { @MainActor [probability] in
                self.lastProbability = probability
                self.isRunning = false
                GlobalSinirSistemi.paylasilan.veriPompala(
                    kategori: .kar,
                    mesaj: "WEALTH CALC: 10$ -> 1M$ analizi bitti.",
                    veri: ["prob": probability, "iterations": iterations]
                )
            }
        }
    }
}
