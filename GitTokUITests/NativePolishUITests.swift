import XCTest

@MainActor final class NativePolishUITests: XCTestCase {
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["GITTOK_BASE_URL"] = "http://127.0.0.1:18580/gittok"
        app.launchEnvironment["GITTOK_PREFERENCES_SUITE"] = "dev.gittok.polish.\(UUID().uuidString)"
        app.launchEnvironment["GITTOK_ONBOARDING"] = "skip"
        app.launchEnvironment["GITTOK_AUTH_DISABLED"] = "1"
        app.launch()
        return app
    }
    func testDiscoverHeaderAndFiltersRemainAvailableWhileScrolling() {
        let app = launch()
        let search = app.buttons["search.open"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        let originalY = search.frame.minY
        app.swipeUp(); app.swipeUp()
        XCTAssertTrue(search.isHittable)
        XCTAssertEqual(search.frame.minY, originalY, accuracy: 2)
        XCTAssertTrue(app.buttons["filter.open"].isHittable)
    }
    func testNativeTabsPreserveRepositoryNavigation() {
        let app = launch()
        let repo = app.buttons["repo.cli/cli"]
        XCTAssertTrue(repo.waitForExistence(timeout: 15)); repo.tap()
        XCTAssertTrue(app.staticTexts["Project preview"].waitForExistence(timeout: 10))
        let saved = app.tabBars.buttons["Saved"]
        XCTAssertTrue(saved.exists, "Navigation must use the native tab bar")
        guard saved.exists else { return }
        saved.tap(); app.tabBars.buttons["Discover"].tap()
        XCTAssertTrue(app.staticTexts["Project preview"].exists)
        app.buttons["Back"].tap()
        XCTAssertTrue(repo.waitForExistence(timeout: 5))
    }
}

@MainActor extension XCUIApplication {
    func launchForReturningUser() {
        launchEnvironment["GITTOK_ONBOARDING"] = "skip"
        launchEnvironment["GITTOK_AUTH_DISABLED"] = "1"
        launch()
    }
}
