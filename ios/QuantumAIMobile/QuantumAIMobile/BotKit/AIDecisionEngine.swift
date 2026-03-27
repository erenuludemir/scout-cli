import Foundation

public enum AISignal {
    case highRisk_Stop
    case neutral_Hold
    case highConviction_Go
}

public final class AIDecisionEngine {
    private var priceHistory: [Double] = []

    public init() {}

    public func analyze(currentPrice: Double) -> AISignal {
        priceHistory.append(currentPrice)
        if priceHistory.count > 50 { priceHistory.removeFirst() }
        guard priceHistory.count >= 10 else { return .neutral_Hold }
        let avg = priceHistory.reduce(0, +) / Double(priceHistory.count)
        let volatility = abs(currentPrice - avg) / max(avg, 1)
        if currentPrice < avg && volatility > 0.02 {
            return .highRisk_Stop
        } else if currentPrice > avg && volatility > 0.015 {
            return .highConviction_Go
        }
        return .neutral_Hold
    }
}
