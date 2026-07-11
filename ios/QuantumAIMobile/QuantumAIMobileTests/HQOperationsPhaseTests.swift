import SwiftUI
import XCTest
@testable import QuantumAIMobile

final class HQOperationsPhaseTests: XCTestCase {
    func testTimelineFilterMatchesSourcesAndAttentionBucket() {
        let operatorItem = makeTimelineItem(source: "OPERATOR", level: .info)
        let backendWarning = makeTimelineItem(source: "BACKEND", level: .warning)
        let deviceCritical = makeTimelineItem(source: "DEVICE", level: .critical)

        XCTAssertTrue(HQOperationTimelineFilter.all.matches(operatorItem))
        XCTAssertTrue(HQOperationTimelineFilter.operatorActions.matches(operatorItem))
        XCTAssertFalse(HQOperationTimelineFilter.backend.matches(operatorItem))
        XCTAssertTrue(HQOperationTimelineFilter.backend.matches(backendWarning))
        XCTAssertTrue(HQOperationTimelineFilter.attention.matches(backendWarning))
        XCTAssertTrue(HQOperationTimelineFilter.attention.matches(deviceCritical))
        XCTAssertFalse(HQOperationTimelineFilter.attention.matches(operatorItem))
    }

    func testTrendSnapshotComputesCurrentPeakAverageAndDelta() {
        let lane = HQRuntimeTrendLane(
            title: "Queue",
            value: "6",
            detail: "pressure",
            tint: .blue,
            points: [2, 4, 6]
        )

        let snapshot = lane.detailSnapshot

        XCTAssertEqual(snapshot.current, 6, accuracy: 0.001)
        XCTAssertEqual(snapshot.peak, 6, accuracy: 0.001)
        XCTAssertEqual(snapshot.average, 4, accuracy: 0.001)
        XCTAssertEqual(snapshot.delta, 4, accuracy: 0.001)
    }

    private func makeTimelineItem(source: String, level: HQEventLevel) -> HQOperationTimelineItem {
        HQOperationTimelineItem(
            timestamp: .now,
            timestampText: "10:00:00",
            source: source,
            module: "TEST",
            title: "ACTION",
            detail: "detail",
            outcome: "SUCCESS",
            level: level
        )
    }
}
