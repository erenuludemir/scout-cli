import XCTest
@testable import QuantumAIMobile

@MainActor
final class SimulationCatalogTests: XCTestCase {
    func testCatalogIncludesAllRequestedVersionFamilies() {
        let expected = Set(SimulationVersion.allCases)
        let actual = Set(SimulationCatalog.all.map(\.version))

        XCTAssertEqual(actual, expected)
    }

    func testEveryBundleHasCompiledModulesAndOverview() {
        for bundle in SimulationCatalog.all {
            XCTAssertFalse(bundle.overview.isEmpty)
            XCTAssertFalse(bundle.modules.isEmpty)
            XCTAssertTrue(bundle.modules.allSatisfy { !$0.originHint.isEmpty })
        }
    }

    func testControlCenterActivatesVersionAndSynchronizes() {
        let sut = SimulationControlCenter(
            bundles: SimulationCatalog.all,
            selectedVersion: .v3,
            activatedVersions: [],
            syncedAt: nil,
            activityLog: []
        )

        sut.bootstrap()
        sut.activate(version: .vOmega)
        sut.synchronizeCatalog()

        XCTAssertEqual(sut.selectedVersion, .vOmega)
        XCTAssertTrue(sut.isActivated(.vOmega))
        XCTAssertNotNil(sut.syncedAt)
        XCTAssertFalse(sut.activityLog.isEmpty)
    }
}
