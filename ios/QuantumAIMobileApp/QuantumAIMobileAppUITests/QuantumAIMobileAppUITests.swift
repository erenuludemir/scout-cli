import XCTest

final class QuantumAIMobileAppUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testBottomNavigationWalletFlow() throws {
        let app = launchApp()

        XCTAssertTrue(app.scrollViews["panel-screen"].waitForExistence(timeout: 10))

        XCTAssertTrue(app.buttons["bottom-tab-wallet"].waitForExistence(timeout: 10))
        app.buttons["bottom-tab-wallet"].tap()
        XCTAssertTrue(app.staticTexts["Cüzdan"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testPanelOperationsMenuOpensMarketBridge() throws {
        let app = launchApp()

        XCTAssertTrue(app.scrollViews["panel-screen"].waitForExistence(timeout: 10))

        let marketBridgeTile = app.descendants(matching: .any)["panel-op-market-bridge"].firstMatch
        XCTAssertTrue(marketBridgeTile.waitForExistence(timeout: 5))
        marketBridgeTile.tap()
        XCTAssertTrue(app.staticTexts["CoinMarketCap Bridge"].waitForExistence(timeout: 5))
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing", "-disable-training-on-launch"]
        app.launch()
        return app
    }

}
