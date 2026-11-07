import XCTest

@MainActor final class OnboardingUITests: XCTestCase {
    private func app(suite: String = UUID().uuidString) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["GITTOK_BASE_URL"] = "http://127.0.0.1:18580/gittok"
        app.launchEnvironment["GITTOK_PREFERENCES_SUITE"] = "dev.gittok.onboarding.\(suite)"
        app.launchEnvironment["GITTOK_AUTH_DISABLED"] = "1"
        return app
    }
    func testFirstRunCapturesProfileAndDoesNotRepeatAfterRelaunch() {
        let app = app(); app.launch()
        XCTAssertTrue(app.buttons["onboarding.continue"].waitForExistence(timeout: 10))
        app.buttons["onboarding.continue"].tap()
        let swift = app.buttons["onboarding.choice.Swift"]
        XCTAssertTrue(swift.waitForExistence(timeout: 5)); swift.tap()
        app.buttons["onboarding.continue"].tap()
        app.buttons["onboarding.choice.Go"].tap()
        app.buttons["onboarding.continue"].tap()
        app.buttons["onboarding.choice.Mobile"].tap()
        app.buttons["onboarding.continue"].tap()
        app.buttons["onboarding.goal.firstContribution"].tap()
        app.buttons["onboarding.continue"].tap()
        XCTAssertTrue(app.tabBars.buttons["You"].waitForExistence(timeout: 10))
        app.terminate(); app.launch()
        XCTAssertTrue(app.tabBars.buttons["You"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["onboarding.continue"].exists)
        app.tabBars.buttons["You"].tap()
        for _ in 0..<8 { if app.buttons["interest.Swift"].isHittable { break }; app.swipeUp() }
        XCTAssertTrue(app.buttons["interest.Swift"].isHittable)
        XCTAssertEqual(app.buttons["interest.Swift"].value as? String, "Selected")
    }
    func testInterruptedDraftResumesAndBackRetainsChoices() {
        let app = app(); app.launch()
        XCTAssertTrue(app.buttons["onboarding.continue"].waitForExistence(timeout: 10)); app.buttons["onboarding.continue"].tap()
        app.buttons["onboarding.choice.Rust"].tap()
        app.buttons["onboarding.continue"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["Make room for something new."].waitForExistence(timeout: 10))
        app.buttons["onboarding.back"].tap()
        XCTAssertEqual(app.buttons["onboarding.choice.Rust"].value as? String, "Selected")
        app.buttons["onboarding.skip"].tap()
        XCTAssertTrue(app.tabBars.buttons["Discover"].waitForExistence(timeout: 10))
    }
    func testUnconfiguredAccountIsHonestAndPublicDiscoveryRemainsAvailable() {
        let app = app(); app.launch()
        XCTAssertTrue(app.buttons["onboarding.skip"].waitForExistence(timeout: 10)); app.buttons["onboarding.skip"].tap()
        app.tabBars.buttons["You"].tap()
        let signIn = app.buttons["account.sign-in"]
        for _ in 0..<5 { if signIn.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(signIn.isHittable); signIn.tap()
        XCTAssertTrue(app.staticTexts["Sign-in is unavailable"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        app.tabBars.buttons["Discover"].tap()
        XCTAssertTrue(app.buttons["repo.cli/cli"].waitForExistence(timeout: 10))
    }
    func testLargestTextKeepsOnboardingActionsUsableAfterRotation() {
        let app = app()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let next = app.buttons["onboarding.continue"]
        XCTAssertTrue(next.waitForExistence(timeout: 10)); XCTAssertTrue(next.isHittable)
        next.tap()
        let heading = app.staticTexts["Start with what you know."]
        XCTAssertGreaterThan(heading.frame.height, 120, "The test must actually render an accessibility text size.")
        let swift = app.buttons["onboarding.choice.Swift"]
        for _ in 0..<10 {
            if swift.isHittable && swift.frame.midY > app.navigationBars.firstMatch.frame.maxY && swift.frame.midY < next.frame.minY { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(swift.isHittable); swift.tap()
        XCTAssertEqual(swift.value as? String, "Selected")
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        XCTAssertTrue(next.isHittable)
        next.tap()
        XCTAssertTrue(app.buttons["onboarding.skip"].isHittable)
        app.buttons["onboarding.skip"].tap()
        XCTAssertTrue(app.tabBars.buttons["Discover"].waitForExistence(timeout: 10))
    }
}
