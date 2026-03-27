import XCTest
@testable import QuantumAIMobile

@MainActor
final class WalletNetworkTests: XCTestCase {
    func testWalletRegistryIncludesMajorNetworks() {
        let ids = Set(WalletChainRegistry.supportedNetworks().map(\.id))

        XCTAssertTrue(ids.contains("ethereum"))
        XCTAssertTrue(ids.contains("base"))
        XCTAssertTrue(ids.contains("tron"))
        XCTAssertTrue(ids.contains("solana"))
        XCTAssertTrue(ids.contains("bitcoin"))
    }

    func testWalletRegistryResolvesAliases() {
        XCTAssertEqual(WalletChainRegistry.network(id: "8453")?.id, "base")
        XCTAssertEqual(WalletChainRegistry.network(id: "trc20")?.id, "tron")
        XCTAssertEqual(WalletChainRegistry.network(id: "btc")?.id, "bitcoin")
    }

    func testWalletServiceExposesSupportedNetworks() {
        let env = AppEnvironment.liveInSim()
        let networks = env.wallet.supportedNetworks()

        XCTAssertGreaterThanOrEqual(networks.count, 8)
        XCTAssertEqual(networks.first?.id, "ethereum")
    }
}
