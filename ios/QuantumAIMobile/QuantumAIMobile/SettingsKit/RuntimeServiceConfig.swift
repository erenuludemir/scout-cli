import Foundation

enum RuntimeServiceConfig {
    private static let defaults = (
        baseURL: URL(string: "http://127.0.0.1:8787")!,
        deviceBaseURL: URL(string: "http://MacBook-Air.local:8787")!,
        ordersPath: "api/orders",
        commandsPath: "v1/commands",
        healthPath: "health",
        readyPath: "ready",
        outboxPath: "admin/outbox",
        outboxEventsPath: "admin/outbox/events",
        outboxDrainPath: "admin/outbox/drain",
        outboxReplayDeadLettersPath: "admin/outbox/replay-dead-letters",
        runbookPath: "admin/runbook",
        runbookDrilldownPath: "admin/runbook/drilldown"
    )

    static var baseURL: URL {
        #if targetEnvironment(simulator)
        return value(for: "APIBaseURL").flatMap(URL.init(string:)) ?? defaults.baseURL
        #else
        return value(for: "DeviceAPIBaseURL").flatMap(URL.init(string:))
            ?? value(for: "APIBaseURL").flatMap(URL.init(string:))
            ?? defaults.deviceBaseURL
        #endif
    }

    static var ordersURL: URL {
        endpointURL(pathKey: "OrdersPath", fallback: defaults.ordersPath)
    }

    static var commandsURL: URL {
        endpointURL(pathKey: "CommandsPath", fallback: defaults.commandsPath)
    }

    static var healthURL: URL {
        endpointURL(pathKey: "HealthPath", fallback: defaults.healthPath)
    }

    static var readyURL: URL {
        endpointURL(pathKey: "ReadyPath", fallback: defaults.readyPath)
    }

    static var outboxStatusURL: URL {
        endpointURL(pathKey: "OutboxPath", fallback: defaults.outboxPath)
    }

    static func outboxEventsURL(status: String? = nil, topic: String? = nil, limit: Int = 25) -> URL {
        var components = URLComponents(url: endpointURL(pathKey: "OutboxEventsPath", fallback: defaults.outboxEventsPath), resolvingAgainstBaseURL: false)
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        if let status, !status.isEmpty {
            queryItems.append(URLQueryItem(name: "status", value: status))
        }
        if let topic, !topic.isEmpty {
            queryItems.append(URLQueryItem(name: "topic", value: topic))
        }
        components?.queryItems = queryItems
        return components?.url ?? endpointURL(pathKey: "OutboxEventsPath", fallback: defaults.outboxEventsPath)
    }

    static var outboxDrainURL: URL {
        endpointURL(pathKey: "OutboxDrainPath", fallback: defaults.outboxDrainPath)
    }

    static func outboxReplayDeadLettersURL(limit: Int = 25) -> URL {
        var components = URLComponents(url: endpointURL(pathKey: "OutboxReplayDeadLettersPath", fallback: defaults.outboxReplayDeadLettersPath), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        return components?.url ?? endpointURL(pathKey: "OutboxReplayDeadLettersPath", fallback: defaults.outboxReplayDeadLettersPath)
    }

    static func runbookURL(
        limit: Int = 12,
        auditAction: [String] = [],
        auditTopic: [String] = [],
        auditStatus: [String] = []
    ) -> URL {
        var components = URLComponents(url: endpointURL(pathKey: "RunbookPath", fallback: defaults.runbookPath), resolvingAgainstBaseURL: false)
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        if !auditAction.isEmpty {
            queryItems.append(URLQueryItem(name: "audit_action", value: auditAction.joined(separator: ",")))
        }
        if !auditTopic.isEmpty {
            queryItems.append(URLQueryItem(name: "audit_topic", value: auditTopic.joined(separator: ",")))
        }
        if !auditStatus.isEmpty {
            queryItems.append(URLQueryItem(name: "audit_status", value: auditStatus.joined(separator: ",")))
        }
        components?.queryItems = queryItems
        return components?.url ?? endpointURL(pathKey: "RunbookPath", fallback: defaults.runbookPath)
    }

    static func runbookDrilldownURL(metric: String, limit: Int = 8) -> URL {
        var components = URLComponents(url: endpointURL(pathKey: "RunbookDrilldownPath", fallback: defaults.runbookDrilldownPath), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "metric", value: metric),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        return components?.url ?? endpointURL(pathKey: "RunbookDrilldownPath", fallback: defaults.runbookDrilldownPath)
    }

    private static func endpointURL(pathKey: String, fallback: String) -> URL {
        let path = value(for: pathKey) ?? fallback
        return baseURL.appending(path: normalized(path))
    }

    private static func value(for key: String) -> String? {
        guard
            let url = ResourceBundle.url(forResource: "SaaS_Config", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else {
            return nil
        }

        return plist[key] as? String
    }

    private static func normalized(_ path: String) -> String {
        path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}
