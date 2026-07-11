import Foundation

public struct RuntimeAdminHealthSnapshot: Equatable {
    public let status: String
    public let service: String
    public let timestampText: String
    public let checks: [String: String]

    public static let empty = RuntimeAdminHealthSnapshot(
        status: "unknown",
        service: "qai-runtime-api",
        timestampText: "",
        checks: [:]
    )

    public var connectedCount: Int {
        checks.values.filter { $0 == "connected" }.count
    }

    public var blockingIssues: [String] {
        checks
            .filter { !["connected", "optional"].contains($0.value) }
            .map { "\($0.key)=\($0.value)" }
            .sorted()
    }
}

public struct RuntimeAdminOutboxSnapshot: Equatable {
    public let pending: Int
    public let processing: Int
    public let failed: Int
    public let deadLetter: Int
    public let sent: Int
    public let due: Int

    public static let empty = RuntimeAdminOutboxSnapshot(
        pending: 0,
        processing: 0,
        failed: 0,
        deadLetter: 0,
        sent: 0,
        due: 0
    )

    public var activeCount: Int {
        pending + processing + failed
    }
}

public struct RuntimeAdminEvent: Identifiable, Equatable {
    public let id: Int
    public let aggregateID: String
    public let topic: String
    public let status: String
    public let attempts: Int
    public let lastError: String?
    public let createdAtText: String
    public let nextAttemptAtText: String
}

public struct RuntimeAdminAuditEntry: Identifiable, Equatable {
    public let id: Int
    public let eventID: Int?
    public let action: String
    public let topic: String
    public let status: String
    public let detail: String?
    public let createdAtText: String
}

public struct RuntimeAdminRunbookSnapshot: Equatable {
    public let topics: [String: String]
    public let auditCounts: [String: Int]
    public let topicActivity: [RuntimeAdminTopicActivity]
    public let trendPoints: [RuntimeAdminTrendPoint]

    public static let empty = RuntimeAdminRunbookSnapshot(
        topics: [:],
        auditCounts: [:],
        topicActivity: [],
        trendPoints: []
    )
}

public struct RuntimeAdminDrilldownSnapshot: Equatable {
    public let metric: String
    public let checks: [String: String]
    public let outbox: RuntimeAdminOutboxSnapshot
    public let recentAudits: [RuntimeAdminAuditEntry]
    public let events: [RuntimeAdminEvent]

    public static let empty = RuntimeAdminDrilldownSnapshot(
        metric: "",
        checks: [:],
        outbox: .empty,
        recentAudits: [],
        events: []
    )

    public var dependencySummary: String {
        let connected = checks.values.filter { $0 == "connected" }.count
        let total = max(checks.count, 1)
        return "\(connected)/\(total)"
    }
}

public struct RuntimeAdminTopicActivity: Identifiable, Equatable {
    public let id: String
    public let topic: String
    public let sentCount: Int
    public let deadLetterCount: Int
    public let replayCount: Int
    public let lastSeenAtText: String

    public init(
        topic: String,
        sentCount: Int,
        deadLetterCount: Int,
        replayCount: Int,
        lastSeenAtText: String
    ) {
        self.id = topic
        self.topic = topic
        self.sentCount = sentCount
        self.deadLetterCount = deadLetterCount
        self.replayCount = replayCount
        self.lastSeenAtText = lastSeenAtText
    }
}

public struct RuntimeAdminTrendPoint: Identifiable, Equatable {
    public let id: String
    public let bucketStartText: String
    public let connectedDependencies: Int
    public let totalDependencies: Int
    public let outboxDue: Int
    public let outboxFailed: Int
    public let outboxDeadLetter: Int
    public let relaySent: Int
    public let relayDeadLetter: Int
    public let relayReplay: Int

    public init(
        bucketStartText: String,
        connectedDependencies: Int,
        totalDependencies: Int,
        outboxDue: Int,
        outboxFailed: Int,
        outboxDeadLetter: Int,
        relaySent: Int,
        relayDeadLetter: Int,
        relayReplay: Int
    ) {
        self.id = bucketStartText
        self.bucketStartText = bucketStartText
        self.connectedDependencies = connectedDependencies
        self.totalDependencies = totalDependencies
        self.outboxDue = outboxDue
        self.outboxFailed = outboxFailed
        self.outboxDeadLetter = outboxDeadLetter
        self.relaySent = relaySent
        self.relayDeadLetter = relayDeadLetter
        self.relayReplay = relayReplay
    }
}

public struct RuntimeAdminDrainResult: Equatable {
    public let claimed: Int
    public let sent: Int
    public let failed: Int
    public let deadLettered: Int
}

@MainActor
public final class RuntimeAdminMonitor: ObservableObject {
    @Published public private(set) var health = RuntimeAdminHealthSnapshot.empty
    @Published public private(set) var readiness = RuntimeAdminHealthSnapshot.empty
    @Published public private(set) var outbox = RuntimeAdminOutboxSnapshot.empty
    @Published public private(set) var runbook = RuntimeAdminRunbookSnapshot.empty
    @Published public private(set) var recentAudits: [RuntimeAdminAuditEntry] = []
    @Published public private(set) var deadLetterEvents: [RuntimeAdminEvent] = []
    @Published public private(set) var retryableEvents: [RuntimeAdminEvent] = []
    @Published public private(set) var isRefreshing = false
    @Published public private(set) var lastUpdatedAt: Date?
    @Published public private(set) var lastAction = "Backend monitor hazırlanıyor"
    @Published public private(set) var lastError: String?

    private let session: URLSession
    private var pollingTask: Task<Void, Never>?
    private var started = false

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public var hasSnapshot: Bool {
        lastUpdatedAt != nil
    }

    public var isReady: Bool {
        readiness.status == "ready" && readiness.blockingIssues.isEmpty
    }

    public var dependencySummary: String {
        let total = max(readiness.checks.count, 1)
        return "\(readiness.connectedCount)/\(total)"
    }

    public var auditSummary: String {
        let sent = runbook.auditCounts["sent", default: 0]
        let deadLetter = runbook.auditCounts["dead_letter", default: 0]
        let replay = runbook.auditCounts["replay", default: 0]
        return "sent \(sent) • dlq \(deadLetter) • replay \(replay)"
    }

    public func startIfNeeded() {
        guard !started else { return }
        started = true
        pollingTask = Task { [weak self] in
            guard let self else { return }
            await self.refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(8))
                await self.refresh()
            }
        }
    }

    public func stop() {
        pollingTask?.cancel()
        pollingTask = nil
        started = false
    }

    @discardableResult
    public func refresh() async -> Bool {
        guard !isRefreshing else { return lastError == nil }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            async let healthPayload: HealthPayload = fetch(RuntimeServiceConfig.healthURL)
            async let readyPayload: HealthPayload = fetch(RuntimeServiceConfig.readyURL)
            async let outboxPayload: OutboxPayload = fetch(RuntimeServiceConfig.outboxStatusURL)
            async let runbookPayload: RunbookPayload = fetch(RuntimeServiceConfig.runbookURL(limit: 8))
            async let deadLettersPayload: OutboxEventsPayload = fetch(RuntimeServiceConfig.outboxEventsURL(status: "dead_letter", limit: 6))
            async let retryablePayload: OutboxEventsPayload = fetch(RuntimeServiceConfig.outboxEventsURL(status: "failed", limit: 6))

            let (healthPayloadValue, readyPayloadValue, outboxPayloadValue, runbookPayloadValue, deadLettersValue, retryableValue) = try await (
                healthPayload,
                readyPayload,
                outboxPayload,
                runbookPayload,
                deadLettersPayload,
                retryablePayload
            )

            health = healthPayloadValue.snapshot
            readiness = readyPayloadValue.snapshot
            outbox = outboxPayloadValue.snapshot
            runbook = runbookPayloadValue.snapshot
            recentAudits = runbookPayloadValue.recentAudits.map(\.audit)
            deadLetterEvents = deadLettersValue.items.map(\.event)
            retryableEvents = retryableValue.items.map(\.event)
            lastUpdatedAt = .now
            lastError = nil
            if lastAction == "Backend monitor hazırlanıyor" {
                lastAction = "Runtime admin sync tamamlandı"
            }
            return true
        } catch {
            lastError = error.localizedDescription
            lastAction = "Runtime admin sync başarısız"
            return false
        }
    }

    @discardableResult
    public func drainOutbox() async -> RuntimeAdminDrainResult? {
        do {
            let payload: DrainPayload = try await post(RuntimeServiceConfig.outboxDrainURL)
            let result = RuntimeAdminDrainResult(
                claimed: payload.claimed,
                sent: payload.sent,
                failed: payload.failed,
                deadLettered: payload.deadLettered
            )
            lastAction = "Drain sent=\(result.sent) failed=\(result.failed) dlq=\(result.deadLettered)"
            _ = await refresh()
            return result
        } catch {
            lastError = error.localizedDescription
            lastAction = "Drain çağrısı başarısız"
            return nil
        }
    }

    @discardableResult
    public func replayDeadLetters(limit: Int = 25) async -> Int? {
        do {
            let payload: ReplayPayload = try await post(RuntimeServiceConfig.outboxReplayDeadLettersURL(limit: limit))
            lastAction = "Replay dead letters=\(payload.replayed)"
            _ = await refresh()
            return payload.replayed
        } catch {
            lastError = error.localizedDescription
            lastAction = "Replay çağrısı başarısız"
            return nil
        }
    }

    func fetchDrilldown(for lane: HQRuntimeTrendLane, limit: Int = 8) async throws -> RuntimeAdminDrilldownSnapshot {
        let payload: DrilldownPayload = try await fetch(
            RuntimeServiceConfig.runbookDrilldownURL(metric: lane.runtimeMetricKey, limit: limit)
        )
        return payload.snapshot
    }

    private func fetch<T: Decodable>(_ url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)
        try validate(response: response)
        return try decode(T.self, from: data)
    }

    private func post<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let (data, response) = try await session.data(for: request)
        try validate(response: response)
        return try decode(T.self, from: data)
    }

    private func validate(response: URLResponse) throws {
        guard
            let http = response as? HTTPURLResponse,
            (200..<300).contains(http.statusCode)
        else {
            throw URLError(.badServerResponse)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }
}

private struct HealthPayload: Decodable {
    let status: String
    let service: String
    let timestamp: String
    let checks: [String: String]

    var snapshot: RuntimeAdminHealthSnapshot {
        RuntimeAdminHealthSnapshot(
            status: status,
            service: service,
            timestampText: timestamp,
            checks: checks
        )
    }
}

private struct OutboxPayload: Decodable {
    let pending: Int
    let processing: Int
    let failed: Int
    let deadLetter: Int
    let sent: Int
    let due: Int

    enum CodingKeys: String, CodingKey {
        case pending
        case processing
        case failed
        case deadLetter = "dead_letter"
        case sent
        case due
    }

    var snapshot: RuntimeAdminOutboxSnapshot {
        RuntimeAdminOutboxSnapshot(
            pending: pending,
            processing: processing,
            failed: failed,
            deadLetter: deadLetter,
            sent: sent,
            due: due
        )
    }
}

private struct OutboxEventsPayload: Decodable {
    let items: [OutboxEventPayload]
}

private struct OutboxEventPayload: Decodable {
    let id: Int
    let aggregateID: String
    let topic: String
    let status: String
    let attempts: Int
    let lastError: String?
    let createdAt: String
    let nextAttemptAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case aggregateID = "aggregate_id"
        case topic
        case status
        case attempts
        case lastError = "last_error"
        case createdAt = "created_at"
        case nextAttemptAt = "next_attempt_at"
    }

    var event: RuntimeAdminEvent {
        RuntimeAdminEvent(
            id: id,
            aggregateID: aggregateID,
            topic: topic,
            status: status,
            attempts: attempts,
            lastError: lastError,
            createdAtText: createdAt,
            nextAttemptAtText: nextAttemptAt
        )
    }
}

private struct ReplayPayload: Decodable {
    let replayed: Int
}

private struct DrainPayload: Decodable {
    let claimed: Int
    let sent: Int
    let failed: Int
    let deadLettered: Int

    enum CodingKeys: String, CodingKey {
        case claimed
        case sent
        case failed
        case deadLettered = "dead_lettered"
    }
}

private struct RunbookPayload: Decodable {
    let topics: [String: String]
    let auditCounts: [String: Int]
    let topicActivity: [TopicActivityPayload]
    let trendPoints: [TrendPointPayload]
    let recentAudits: [AuditPayload]

    enum CodingKeys: String, CodingKey {
        case topics
        case auditCounts = "audit_counts"
        case topicActivity = "topic_activity"
        case trendPoints = "trend_points"
        case recentAudits = "recent_audits"
    }

    var snapshot: RuntimeAdminRunbookSnapshot {
        RuntimeAdminRunbookSnapshot(
            topics: topics,
            auditCounts: auditCounts,
            topicActivity: topicActivity.map(\.activity),
            trendPoints: trendPoints.map(\.point)
        )
    }
}

private struct DrilldownPayload: Decodable {
    let metric: String
    let checks: [String: String]
    let outbox: OutboxPayload
    let recentAudits: [AuditPayload]
    let events: [OutboxEventPayload]

    enum CodingKeys: String, CodingKey {
        case metric
        case checks
        case outbox
        case recentAudits = "recent_audits"
        case events
    }

    var snapshot: RuntimeAdminDrilldownSnapshot {
        RuntimeAdminDrilldownSnapshot(
            metric: metric,
            checks: checks,
            outbox: outbox.snapshot,
            recentAudits: recentAudits.map(\.audit),
            events: events.map(\.event)
        )
    }
}

private struct TopicActivityPayload: Decodable {
    let topic: String
    let sentCount: Int
    let deadLetterCount: Int
    let replayCount: Int
    let lastSeenAt: String?

    enum CodingKeys: String, CodingKey {
        case topic
        case sentCount = "sent_count"
        case deadLetterCount = "dead_letter_count"
        case replayCount = "replay_count"
        case lastSeenAt = "last_seen_at"
    }

    var activity: RuntimeAdminTopicActivity {
        RuntimeAdminTopicActivity(
            topic: topic,
            sentCount: sentCount,
            deadLetterCount: deadLetterCount,
            replayCount: replayCount,
            lastSeenAtText: lastSeenAt ?? "—"
        )
    }
}

private struct TrendPointPayload: Decodable {
    let bucketStart: String
    let connectedDependencies: Int
    let totalDependencies: Int
    let outboxDue: Int
    let outboxFailed: Int
    let outboxDeadLetter: Int
    let relaySent: Int
    let relayDeadLetter: Int
    let relayReplay: Int

    enum CodingKeys: String, CodingKey {
        case bucketStart = "bucket_start"
        case connectedDependencies = "connected_dependencies"
        case totalDependencies = "total_dependencies"
        case outboxDue = "outbox_due"
        case outboxFailed = "outbox_failed"
        case outboxDeadLetter = "outbox_dead_letter"
        case relaySent = "relay_sent"
        case relayDeadLetter = "relay_dead_letter"
        case relayReplay = "relay_replay"
    }

    var point: RuntimeAdminTrendPoint {
        RuntimeAdminTrendPoint(
            bucketStartText: bucketStart,
            connectedDependencies: connectedDependencies,
            totalDependencies: totalDependencies,
            outboxDue: outboxDue,
            outboxFailed: outboxFailed,
            outboxDeadLetter: outboxDeadLetter,
            relaySent: relaySent,
            relayDeadLetter: relayDeadLetter,
            relayReplay: relayReplay
        )
    }
}

private struct AuditPayload: Decodable {
    let id: Int
    let eventID: Int?
    let action: String
    let topic: String
    let status: String
    let detail: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case eventID = "event_id"
        case action
        case topic
        case status
        case detail
        case createdAt = "created_at"
    }

    var audit: RuntimeAdminAuditEntry {
        RuntimeAdminAuditEntry(
            id: id,
            eventID: eventID,
            action: action,
            topic: topic,
            status: status,
            detail: detail,
            createdAtText: createdAt
        )
    }
}

private extension HQRuntimeTrendLane {
    var runtimeMetricKey: String {
        let normalized = title.lowercased()
        if normalized.contains("queue") {
            return "queue"
        }
        if normalized.contains("relay") {
            return "relay"
        }
        if normalized.contains("replay") {
            return "replay"
        }
        return "deps"
    }
}
