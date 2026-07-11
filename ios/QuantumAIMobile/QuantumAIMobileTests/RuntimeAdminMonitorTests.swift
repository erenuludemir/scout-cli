import SwiftUI
import XCTest
@testable import QuantumAIMobile

final class RuntimeAdminMonitorTests: XCTestCase {
    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    @MainActor
    func testRefreshLoadsHealthOutboxAndRecentEvents() async {
        let session = makeSession()
        StubURLProtocol.handler = { request in
            switch request.url?.path {
            case "/health":
                return Self.response(body: """
                {"status":"ok","service":"qai-runtime-api","timestamp":"2026-04-11T10:00:00Z","checks":{"sqlite":"connected","postgres":"connected","redis":"connected","kafka":"connected"}}
                """)
            case "/ready":
                return Self.response(body: """
                {"status":"ready","service":"qai-runtime-api","timestamp":"2026-04-11T10:00:01Z","checks":{"sqlite":"connected","postgres":"connected","redis":"connected","kafka":"connected"}}
                """)
            case "/admin/outbox":
                return Self.response(body: """
                {"pending":2,"processing":1,"failed":1,"dead_letter":1,"sent":7,"due":3}
                """)
            case "/admin/runbook":
                return Self.response(body: """
                {"topics":{"orders":"orders.incoming","dead_letter":"orders.dead_letter","replay":"orders.replay"},"audit_counts":{"sent":7,"dead_letter":1,"replay":2},"topic_activity":[{"topic":"orders.dead_letter","sent_count":0,"dead_letter_count":1,"replay_count":0,"last_seen_at":"2026-04-11 10:01:05"}],"trend_points":[{"bucket_start":"2026-04-11 10:01:00","connected_dependencies":4,"total_dependencies":4,"outbox_due":3,"outbox_failed":1,"outbox_dead_letter":1,"relay_sent":7,"relay_dead_letter":1,"relay_replay":2}],"recent_audits":[{"id":9,"event_id":41,"action":"dead_letter","topic":"orders.dead_letter","status":"published","detail":"NoBrokersAvailable","created_at":"2026-04-11 10:01:05"}]}
                """)
            case "/admin/outbox/events":
                if request.url?.query?.contains("status=dead_letter") == true {
                    return Self.response(body: """
                    {"items":[{"id":41,"aggregate_id":"order-41","topic":"orders.incoming","status":"dead_letter","attempts":3,"last_error":"NoBrokersAvailable","created_at":"2026-04-11 10:01:00","next_attempt_at":"2026-04-11 10:05:00"}],"count":1}
                    """)
                }
                return Self.response(body: """
                {"items":[{"id":17,"aggregate_id":"order-17","topic":"orders.incoming","status":"failed","attempts":2,"last_error":"timeout","created_at":"2026-04-11 10:02:00","next_attempt_at":"2026-04-11 10:06:00"}],"count":1}
                """)
            default:
                return Self.response(statusCode: 404, body: "{}")
            }
        }

        let sut = RuntimeAdminMonitor(session: session)
        let refreshed = await sut.refresh()

        XCTAssertTrue(refreshed)
        XCTAssertTrue(sut.isReady)
        XCTAssertEqual(sut.dependencySummary, "4/4")
        XCTAssertEqual(sut.outbox.pending, 2)
        XCTAssertEqual(sut.outbox.deadLetter, 1)
        XCTAssertEqual(sut.deadLetterEvents.first?.id, 41)
        XCTAssertEqual(sut.retryableEvents.first?.aggregateID, "order-17")
        XCTAssertEqual(sut.runbook.topics["dead_letter"], "orders.dead_letter")
        XCTAssertEqual(sut.runbook.topicActivity.first?.topic, "orders.dead_letter")
        XCTAssertEqual(sut.runbook.trendPoints.first?.relaySent, 7)
        XCTAssertEqual(sut.recentAudits.first?.action, "dead_letter")
        XCTAssertEqual(sut.auditSummary, "sent 7 • dlq 1 • replay 2")
    }

    @MainActor
    func testReplayAndDrainUpdateLastAction() async {
        let session = makeSession()
        StubURLProtocol.handler = { request in
            switch (request.httpMethod, request.url?.path) {
            case ("POST", "/admin/outbox/replay-dead-letters"):
                return Self.response(body: #"{"replayed":2}"#)
            case ("POST", "/admin/outbox/drain"):
                return Self.response(body: #"{"claimed":2,"sent":2,"failed":0,"dead_lettered":0}"#)
            case (_, "/health"):
                return Self.response(body: #"{"status":"ok","service":"qai-runtime-api","timestamp":"2026-04-11T10:00:00Z","checks":{"sqlite":"connected","postgres":"connected","redis":"connected","kafka":"connected"}}"#)
            case (_, "/ready"):
                return Self.response(body: #"{"status":"ready","service":"qai-runtime-api","timestamp":"2026-04-11T10:00:01Z","checks":{"sqlite":"connected","postgres":"connected","redis":"connected","kafka":"connected"}}"#)
            case (_, "/admin/outbox"):
                return Self.response(body: #"{"pending":0,"processing":0,"failed":0,"dead_letter":0,"sent":9,"due":0}"#)
            case (_, "/admin/runbook"):
                return Self.response(body: #"{"topics":{"orders":"orders.incoming","dead_letter":"orders.dead_letter","replay":"orders.replay"},"audit_counts":{"sent":9,"dead_letter":0,"replay":2},"topic_activity":[],"trend_points":[],"recent_audits":[]}"#)
            case (_, "/admin/outbox/events"):
                return Self.response(body: #"{"items":[],"count":0}"#)
            default:
                return Self.response(statusCode: 404, body: "{}")
            }
        }

        let sut = RuntimeAdminMonitor(session: session)
        let replayed = await sut.replayDeadLetters(limit: 10)
        let drained = await sut.drainOutbox()

        XCTAssertEqual(replayed, 2)
        XCTAssertEqual(drained?.sent, 2)
        XCTAssertEqual(sut.outbox.sent, 9)
        XCTAssertEqual(sut.lastAction, "Drain sent=2 failed=0 dlq=0")
    }

    @MainActor
    func testFetchDrilldownLoadsFilteredAuditsAndEvents() async throws {
        let session = makeSession()
        StubURLProtocol.handler = { request in
            switch request.url?.path {
            case "/admin/runbook/drilldown":
                XCTAssertTrue(request.url?.query?.contains("metric=replay") == true)
                return Self.response(body: """
                {"metric":"replay","checks":{"sqlite":"connected","postgres":"connected","redis":"connected","kafka":"connected"},"outbox":{"pending":0,"processing":0,"failed":1,"dead_letter":1,"sent":9,"due":1},"recent_audits":[{"id":12,"event_id":41,"action":"replay","topic":"orders.replay","status":"published","detail":"admin.bulk","created_at":"2026-04-11 10:05:00"}],"events":[{"id":41,"aggregate_id":"order-41","topic":"orders.incoming","status":"dead_letter","attempts":3,"last_error":"NoBrokersAvailable","created_at":"2026-04-11 10:01:00","next_attempt_at":"2026-04-11 10:05:00"}]}
                """)
            default:
                return Self.response(statusCode: 404, body: "{}")
            }
        }

        let sut = RuntimeAdminMonitor(session: session)
        let lane = HQRuntimeTrendLane(
            title: "Replay",
            value: "2",
            detail: "recoveries",
            tint: .blue,
            points: [0, 1, 2]
        )

        let snapshot = try await sut.fetchDrilldown(for: lane)

        XCTAssertEqual(snapshot.metric, "replay")
        XCTAssertEqual(snapshot.dependencySummary, "4/4")
        XCTAssertEqual(snapshot.outbox.deadLetter, 1)
        XCTAssertEqual(snapshot.recentAudits.first?.action, "replay")
        XCTAssertEqual(snapshot.events.first?.aggregateID, "order-41")
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private static func response(statusCode: Int = 200, body: String) -> (HTTPURLResponse, Data) {
        let url = URL(string: "http://127.0.0.1")!
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        return (response, Data(body.utf8))
    }
}

private final class StubURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
