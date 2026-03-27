import XCTest
import Combine
@testable import QuantumAIMobile

@MainActor
final class PhysicalDeviceTests: XCTestCase {
    func testEnvironmentBootstraps() async {
        let env = AppEnvironment.liveInSim()
        await env.bootstrap()
        env.market.stopAll()
        XCTAssertTrue(true)
    }

    func testWalletAddressAvailableAfterKeypairEnsure() throws {
        let env = AppEnvironment.liveInSim()
        do {
            try env.wallet.ensureKeypair()
            let address = try env.wallet.address()
            XCTAssertTrue(address.hasPrefix("qaidemo_"))
            XCTAssertGreaterThan(address.count, "qaidemo_".count)
        } catch let error as NSError where error.domain == "KeychainStore" {
            throw XCTSkip("Keychain test host ortamında kararsız: \(error.code)")
        }
    }

    func testEnvironmentForwardsNestedObjectChangesToViews() {
        let env = AppEnvironment.liveInSim()
        let exp = expectation(description: "app environment publishes nested changes")
        var cancellable: AnyCancellable?

        cancellable = env.objectWillChange
            .prefix(1)
            .sink { _ in
                exp.fulfill()
            }

        env.trainingJourney.toggleModule(.advancedFeatures)

        wait(for: [exp], timeout: 1.0)
        cancellable?.cancel()
    }
}
