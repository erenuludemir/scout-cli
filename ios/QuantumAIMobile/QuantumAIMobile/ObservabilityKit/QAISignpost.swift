import Foundation
import OSLog

@available(iOS 15.0, macOS 12.0, *)
public enum QAISignpost {
    private static let signposter = OSSignposter(
        subsystem: "com.quantumai.mobile",
        category: .pointsOfInterest
    )
    private static let verboseEventsEnabled = ProcessInfo.processInfo.environment["QAI_VERBOSE_METRICS"] == "1"
    private static let logger = Logger(
        subsystem: "com.quantumai.mobile",
        category: "points-of-interest"
    )

    @discardableResult
    public static func begin(_ name: StaticString) -> OSSignpostIntervalState {
        signposter.beginInterval(name)
    }

    public static func end(_ name: StaticString, _ state: OSSignpostIntervalState) {
        signposter.endInterval(name, state)
    }

    public static func event(_ name: StaticString) {
        signposter.emitEvent(name)
    }

    public static func event(_ name: StaticString, message: String) {
        if verboseEventsEnabled {
            logger.debug("\(message, privacy: .public)")
        }
        signposter.emitEvent(name)
    }
}
