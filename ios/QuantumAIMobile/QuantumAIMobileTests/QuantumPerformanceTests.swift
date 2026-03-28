import XCTest
@testable import QuantumAIMobile

final class QuantumPerformanceTests: XCTestCase {
    func testQuantumMetricsSnapshotKeepsClassicalThreatHigh() {
        let logs = [
            PQCLogEntry(timestamp: Date(), protocolName: "Kyber-768", action: "Encapsulation", latencyMs: 145, noiseLevel: 81, isAIOptimized: false),
            PQCLogEntry(timestamp: Date(), protocolName: "Dilithium3", action: "Signature Verify", latencyMs: 132, noiseLevel: 76, isAIOptimized: false)
        ]

        let snapshot = QuantumMetricsSnapshot.reduce(logs: logs, isAIOptimized: false, qkdStatus: "ESTABLISHED")

        XCTAssertGreaterThan(snapshot.pqcLatency, 100)
        XCTAssertGreaterThan(snapshot.nisqNoiseLevel, 70)
        XCTAssertEqual(snapshot.multiplierText, "1x")
        XCTAssertEqual(snapshot.threatLevel, "YUKSEK (KUANTUM SALDIRI RISKI)")
    }

    func testQuantumMetricsSnapshotPromotesOptimizedMode() {
        let logs = [
            PQCLogEntry(timestamp: Date(), protocolName: "Kyber-1024", action: "Encapsulation", latencyMs: 10, noiseLevel: 8, isAIOptimized: true),
            PQCLogEntry(timestamp: Date(), protocolName: "Falcon-512", action: "Signature Verify", latencyMs: 12, noiseLevel: 7, isAIOptimized: true)
        ]

        let snapshot = QuantumMetricsSnapshot.reduce(logs: logs, isAIOptimized: true, qkdStatus: "ESTABLISHED")

        XCTAssertLessThan(snapshot.averageLatency, 20)
        XCTAssertLessThan(snapshot.averageNoise, 20)
        XCTAssertGreaterThan(snapshot.qkdKeyRate, 120)
        XCTAssertNotEqual(snapshot.multiplierText, "1x")
        XCTAssertEqual(snapshot.threatLevel, "NOTR (PQC + QKD ZIRHI AKTIF)")
    }

    func testQuantumMetricsSnapshotFlagsCompromisedQKD() {
        let snapshot = QuantumMetricsSnapshot.reduce(logs: [], isAIOptimized: true, qkdStatus: "COMPROMISED")
        XCTAssertEqual(snapshot.threatLevel, "KRITIK (QKD HATTI KOMPROMIZE)")
    }

    func testTerminalLogParserExtractsProtocolAndLatency() {
        let line = "[07:22:01] [Kyber-768] Encapsulation tamamlandi. Gecikme: 12.40ms Noise: 7.5% AI AKTIF"

        guard let entry = PQCLogEntry.parseTerminalLine(line) else {
            return XCTFail("Terminal satiri parse edilemedi")
        }

        XCTAssertEqual(entry.protocolName, "Kyber-768")
        XCTAssertEqual(entry.action, "Encapsulation tamamlandi")
        XCTAssertEqual(entry.latencyMs, 12.4, accuracy: 0.001)
        XCTAssertEqual(entry.noiseLevel, 7.5, accuracy: 0.001)
        XCTAssertEqual(entry.isAIOptimized, true)
    }

    func testQuantumBacktrackingTreeFindsAcceptedPath() async {
        let tree = QuantumBacktrackingTree(
            maxDepth: 3,
            branchQA: QuantumArray(size: 2),
            accept: { node in QuantumBool(state: node.path == [1, 0, 1]) },
            reject: { node in QuantumBool(state: node.path == [0, 0]) }
        )

        await tree.initPhi(path: [])
        await tree.quantumStep(controls: [QuantumBool(state: true)])
        let solution = await tree.findSolution(precision: 4)
        let evaluation = await tree.evaluation()

        XCTAssertEqual(solution, [1, 0, 1])
        XCTAssertEqual(evaluation.solutionPath, [1, 0, 1])
        XCTAssertGreaterThan(evaluation.evaluatedNodes, 0)
        XCTAssertTrue(evaluation.graphSummary.contains("Graph("))
    }

    func testQuantumBacktrackingPlannerEscalatesCompromisedHierarchy() async {
        let planner = QuantumBacktrackingPlanner()
        let plan = await planner.optimize(
            workload: QuantumWorkloadMetrics(
                averageLatency: 148,
                averageNoise: 81,
                qkdStatus: "COMPROMISED",
                isAIOptimized: false,
                retainedLogCount: 24,
                branchFactor: 3,
                searchDepth: 5,
                precision: 4
            )
        )

        XCTAssertFalse(plan.hierarchy.priorities.isEmpty)
        XCTAssertEqual(plan.hierarchy.priorities.first?.level, .critical)
        XCTAssertEqual(plan.hierarchy.priorities.first?.id, "noise-stabilize")
        XCTAssertEqual(plan.evaluation.symbolicComplexity, "O(sqrt(T) n^(3/2) log n)")
    }
}
