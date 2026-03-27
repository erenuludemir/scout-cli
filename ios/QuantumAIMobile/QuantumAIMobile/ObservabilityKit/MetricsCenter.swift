import Foundation
import OSLog

public final class MetricsCenter {
    private let logger = Logger(subsystem: "com.quantumai.mobile", category: "metrics")
    private let verboseLoggingEnabled = ProcessInfo.processInfo.environment["QAI_VERBOSE_METRICS"] == "1"
    public private(set) var tickCount = 0
    public private(set) var alertCount = 0
    public private(set) var retryCount = 0
    public private(set) var latenciesMs: [Double] = []

    public init() {}

    public func recordTick() {
        tickCount += 1
        if verboseLoggingEnabled && tickCount % 1000 == 0 {
            logger.debug("tick_count=\(self.tickCount)")
        }
    }

    public func recordAlert() {
        alertCount += 1
        guard verboseLoggingEnabled else { return }
        logger.debug("alert_count=\(self.alertCount)")
    }

    public func recordRetry() {
        retryCount += 1
        guard verboseLoggingEnabled else { return }
        logger.debug("retry_count=\(self.retryCount)")
    }

    public func recordError(_ message: String) {
        logger.error("\(message)")
    }

    public func recordOrderLatency(_ ms: Double) {
        latenciesMs.append(ms)
        if latenciesMs.count > 2048 {
            latenciesMs.removeFirst(latenciesMs.count - 2048)
        }
        guard verboseLoggingEnabled else { return }
        logger.debug("order_latency_ms=\(ms, format: .fixed(precision: 2))")
    }

    public func p95() -> Double {
        percentile(95)
    }

    public func percentile(_ p: Int) -> Double {
        let sorted = latenciesMs.sorted()
        guard !sorted.isEmpty else { return 0 }
        let index = min(max(Int(Double(sorted.count - 1) * Double(p) / 100.0), 0), sorted.count - 1)
        return sorted[index]
    }
}
