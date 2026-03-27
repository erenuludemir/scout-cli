import XCTest

final class QuantumAIMobileAppUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testBottomNavigationAndMarketBridgeBackFlow() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing", "-disable-training-on-launch"]
        app.launch()

        let panelTab = app.buttons["bottom-tab-panel"]
        XCTAssertTrue(panelTab.waitForExistence(timeout: 10))

        let settingsTab = app.buttons["bottom-tab-settings"]
        XCTAssertTrue(settingsTab.exists)
        settingsTab.tap()

        XCTAssertTrue(app.staticTexts["Ayarlar"].waitForExistence(timeout: 5))

        let marketBridgeLink = app.buttons["settings-link-market-bridge"]
        XCTAssertTrue(marketBridgeLink.waitForExistence(timeout: 5))
        marketBridgeLink.tap()

        XCTAssertTrue(app.staticTexts["Market Bridge"].waitForExistence(timeout: 5))

        let backButton = app.buttons["screen-header-back"]
        XCTAssertTrue(backButton.waitForExistence(timeout: 5))
        backButton.tap()

        XCTAssertTrue(app.staticTexts["Ayarlar"].waitForExistence(timeout: 5))

        let walletTab = app.buttons["bottom-tab-wallet"]
        XCTAssertTrue(walletTab.exists)
        walletTab.tap()

        XCTAssertTrue(app.staticTexts["Cüzdan"].waitForExistence(timeout: 5))
    }
}
