import XCTest

final class QuantumAIMobileAppUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testBottomNavigationPrimaryTabsFlow() throws {
        let app = launchApp()

        assertPanelVisible(in: app)

        tapTab("markets", in: app)
        XCTAssertTrue(app.scrollViews["market-bridge-screen"].waitForExistence(timeout: 5))

        tapTab("bots", in: app)
        XCTAssertTrue(app.staticTexts["DCA Motoru"].waitForExistence(timeout: 5))

        tapTab("settings", in: app)
        XCTAssertTrue(app.scrollViews["settings-screen"].waitForExistence(timeout: 5))

        tapTab("panel", in: app)
        assertPanelVisible(in: app)
    }

    @MainActor
    func testPanelOperationsMenuOpensMarketBridge() throws {
        let app = launchApp()

        assertPanelVisible(in: app)

        let marketBridgeTile = app.descendants(matching: .any)["panel-op-market-bridge"].firstMatch
        XCTAssertTrue(marketBridgeTile.waitForExistence(timeout: 5))
        marketBridgeTile.tap()
        XCTAssertTrue(app.scrollViews["market-bridge-screen"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSettingsLinkOpensMarketBridge() throws {
        let app = launchApp()

        tapTab("settings", in: app)
        XCTAssertTrue(app.scrollViews["settings-screen"].waitForExistence(timeout: 5))

        let marketBridgeLink = app.descendants(matching: .any)["settings-link-market-bridge"].firstMatch
        XCTAssertTrue(marketBridgeLink.waitForExistence(timeout: 5))
        marketBridgeLink.tap()
        XCTAssertTrue(app.scrollViews["market-bridge-screen"].waitForExistence(timeout: 5))
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui-testing",
            "-ui-testing-static-runtime",
            "-disable-training-on-launch"
        ]
        app.launch()
        return app
    }

    private func tapTab(_ name: String, in app: XCUIApplication) {
        let button = app.buttons["bottom-tab-\(name)"]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.tap()
    }

    private func assertPanelVisible(in app: XCUIApplication) {
        XCTAssertTrue(app.scrollViews["panel-screen"].waitForExistence(timeout: 10))
    }
}
