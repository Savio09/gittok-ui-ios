import XCTest

/// Opt-in real development-provider test. Uses Clerk's documented non-delivery
/// +clerk_test address/OTP, never a real person's email or credentials.
@MainActor final class ClerkAcceptanceUITests: XCTestCase {
    func testDevelopmentEmailSessionRestoresAndOwnersRemainSeparate() throws {
        guard ProcessInfo.processInfo.environment["GITTOK_LIVE_AUTH"] == "1" else {
            throw XCTSkip("Set TEST_RUNNER_GITTOK_LIVE_AUTH=1 and provision the documented development test user before running this acceptance test.")
        }
        let app = XCUIApplication()
        app.launchEnvironment["GITTOK_BASE_URL"] = "http://127.0.0.1:18580/gittok"
        app.launchEnvironment["GITTOK_ONBOARDING"] = "skip"
        app.launchEnvironment["GITTOK_PREFERENCES_SUITE"] = "dev.gittok.live-auth.\(UUID().uuidString)"
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["You"].waitForExistence(timeout: 15)); app.tabBars.buttons["You"].tap()
        guard !app.buttons["account.sign-out"].exists else { throw XCTSkip("An existing user is signed in; this test does not replace their session.") }
        app.tabBars.buttons["Discover"].tap()
        let save = app.buttons["save.cli/cli"]
        XCTAssertTrue(save.waitForExistence(timeout: 15)); save.tap()
        app.tabBars.buttons["You"].tap(); app.buttons["account.sign-in"].tap()
        let email = app.textFields["clerk.auth.start.identifier"]
        XCTAssertTrue(email.waitForExistence(timeout: 20), app.debugDescription)
        XCTAssertTrue(app.buttons["clerk.auth.socialProvider.oauth_github"].exists)
        let fixtureEmail = "native-polish+clerk_test@example.com"
        if let previous = email.value as? String, previous.contains("@") {
            guard previous == fixtureEmail else { throw XCTSkip("Clear the prefilled identifier before this fixture test; it does not overwrite another identifier.") }
        } else { email.tap(); email.typeText(fixtureEmail) }
        XCTAssertEqual(email.value as? String, fixtureEmail)
        app.buttons["clerk.auth.start.continue"].tap()
        let code = app.textFields["clerk.auth.signIn.code"]
        if !code.waitForExistence(timeout: 5), app.buttons["clerk.auth.signIn.useAnotherMethod"].exists {
            app.buttons["clerk.auth.signIn.useAnotherMethod"].tap()
            app.buttons["clerk.auth.signIn.alternativeMethod.email_code"].tap()
        }
        XCTAssertTrue(code.waitForExistence(timeout: 15), app.debugDescription)
        code.tap(); code.typeText("424242")
        if app.buttons["clerk.auth.signIn.continue"].isHittable { app.buttons["clerk.auth.signIn.continue"].tap() }
        XCTAssertTrue(app.tabBars.buttons["You"].waitForExistence(timeout: 15)); app.tabBars.buttons["You"].tap()
        XCTAssertTrue(app.buttons["account.sign-out"].waitForExistence(timeout: 15), app.debugDescription)
        app.tabBars.buttons["Saved"].tap()
        XCTAssertTrue(app.staticTexts["Keep something good."].waitForExistence(timeout: 10))
        app.terminate(); app.launch()
        XCTAssertTrue(app.tabBars.buttons["You"].waitForExistence(timeout: 15)); app.tabBars.buttons["You"].tap()
        XCTAssertTrue(app.buttons["account.sign-out"].waitForExistence(timeout: 10))
        app.buttons["account.sign-out"].tap()
        XCTAssertTrue(app.tabBars.buttons["Saved"].waitForExistence(timeout: 15)); app.tabBars.buttons["Saved"].tap()
        XCTAssertTrue(app.buttons["saved.cli/cli"].waitForExistence(timeout: 10), app.debugDescription)
    }
}
