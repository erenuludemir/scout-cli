import Foundation
import OSLog

public enum NetworkNoisePolicy {
    public static func isTransient(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .timedOut,
             .cannotFindHost,
             .cannotConnectToHost,
             .dnsLookupFailed,
             .networkConnectionLost,
             .notConnectedToInternet,
             .internationalRoamingOff,
             .callIsActive,
             .dataNotAllowed,
             .backgroundSessionWasDisconnected:
            return true
        default:
            return false
        }
    }
}

public actor ResilientRequestExecutor {
    public struct Policy: Sendable {
        public let requestTimeout: TimeInterval
        public let resourceTimeout: TimeInterval
        public let waitsForConnectivity: Bool
        public let maxAttempts: Int
        public let baseDelayNanoseconds: UInt64
        public let maxDelayNanoseconds: UInt64

        public init(
            requestTimeout: TimeInterval = 15,
            resourceTimeout: TimeInterval = 30,
            waitsForConnectivity: Bool = true,
            maxAttempts: Int = 4,
            baseDelayNanoseconds: UInt64 = 500_000_000,
            maxDelayNanoseconds: UInt64 = 8_000_000_000
        ) {
            self.requestTimeout = requestTimeout
            self.resourceTimeout = resourceTimeout
            self.waitsForConnectivity = waitsForConnectivity
            self.maxAttempts = max(1, maxAttempts)
            self.baseDelayNanoseconds = baseDelayNanoseconds
            self.maxDelayNanoseconds = maxDelayNanoseconds
        }
    }

    private let logger = Logger(subsystem: "com.erenuludemir.quantumaimobile", category: "network")
    private let session: URLSession
    private let policy: Policy

    public init(policy: Policy = Policy()) {
        self.policy = policy
        let config = URLSessionConfiguration.ephemeral
        config.waitsForConnectivity = policy.waitsForConnectivity
        config.timeoutIntervalForRequest = policy.requestTimeout
        config.timeoutIntervalForResource = policy.resourceTimeout
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.httpShouldUsePipelining = false
        config.httpMaximumConnectionsPerHost = 4
        config.urlCache = nil
        config.allowsExpensiveNetworkAccess = true
        config.allowsConstrainedNetworkAccess = true
        self.session = URLSession(configuration: config)
    }

    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        var prepared = request
        if prepared.timeoutInterval <= 0 {
            prepared.timeoutInterval = policy.requestTimeout
        }
        if prepared.value(forHTTPHeaderField: "Connection") == nil {
            prepared.setValue("close", forHTTPHeaderField: "Connection")
        }

        var attempt = 0
        var lastError: Error?

        while attempt < policy.maxAttempts {
            attempt += 1
            do {
                logger.info("network_request_start attempt=\(attempt, privacy: .public) url=\(prepared.url?.absoluteString ?? "unknown", privacy: .public)")
                let result = try await session.data(for: prepared)
                if let http = result.1 as? HTTPURLResponse, (500...599).contains(http.statusCode), attempt < policy.maxAttempts {
                    let delay = nextDelay(for: attempt)
                    logger.warning("network_request_retry status=\(http.statusCode, privacy: .public) attempt=\(attempt, privacy: .public) delay_ns=\(delay, privacy: .public)")
                    try await Task.sleep(nanoseconds: delay)
                    continue
                }
                logger.info("network_request_success attempt=\(attempt, privacy: .public)")
                return result
            } catch {
                lastError = error
                let transient = NetworkNoisePolicy.isTransient(error)
                logger.error("network_request_failure transient=\(transient, privacy: .public) attempt=\(attempt, privacy: .public) error=\(String(describing: error), privacy: .public)")
                guard transient, attempt < policy.maxAttempts else {
                    throw error
                }
                try await Task.sleep(nanoseconds: nextDelay(for: attempt))
            }
        }

        throw lastError ?? URLError(.unknown)
    }

    public func decoded<T: Decodable>(_ type: T.Type, for request: URLRequest, decoder: JSONDecoder = JSONDecoder()) async throws -> T {
        let (data, _) = try await self.data(for: request)
        return try decoder.decode(T.self, from: data)
    }

    private func nextDelay(for attempt: Int) -> UInt64 {
        let multiplier = UInt64(1 << max(0, attempt - 1))
        let raw = policy.baseDelayNanoseconds * multiplier
        return min(raw, policy.maxDelayNanoseconds)
    }
}
