import XCTest

final class GitTokUITests: XCTestCase {
    @MainActor func testConnectionAndRepositoryValidation() {
        let app = XCUIApplication()
        app.launchEnvironment["GITTOK_BASE_URL"] = "http://localhost:1"
        app.launch()
        XCTAssertTrue(app.buttons["lookup.open"].waitForExistence(timeout: 10))
        app.buttons["lookup.open"].tap()
        let input = app.textFields["lookup.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap(); input.typeText("invalid")
        app.buttons["lookup.submit"].tap()
        XCTAssertTrue(app.staticTexts["lookup.error"].exists)
        XCTAssertTrue(app.staticTexts["Source review only. Software is not executed."].exists)
    }
    @MainActor func testBackendFailureHasRetryAndSettings() {
        let app = XCUIApplication()
        app.launchEnvironment["GITTOK_BASE_URL"] = "http://localhost:1"
        app.launch()
        XCTAssertTrue(app.buttons["Try again"].waitForExistence(timeout: 15))
        app.buttons["settings.open"].tap()
        XCTAssertTrue(app.textFields["settings.url"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings.save"].exists)
    }
}

/// These tests call the checked-in local Postman simulation, never live GitHub.
/// Start the simulation before xcodebuild test; see README.md.
@MainActor final class GitTokIntegrationUITests: XCTestCase {
    private let baseURL = "http://127.0.0.1:18080/gittok"
    private func launch(_ scenario: String = "") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["GITTOK_BASE_URL"] = baseURL + scenario
        app.launch()
        return app
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<12 {
            if element.isHittable { return }
            app.swipeUp()
        }
    }
    func testRealSnapshotFeedToAllClassificationSources() {
        let app = launch()
        let repo = app.buttons["repo.cli/cli"]
        XCTAssertTrue(repo.waitForExistence(timeout: 15), "Start the local Postman simulation on port 18080 before running native tests.")
        capture(app, "01-folio-discover-real-snapshots")
        reveal(repo, in: app); repo.tap()
        let claim = app.buttons["claim.Why this is a CLI"]
        XCTAssertTrue(claim.waitForExistence(timeout: 10))
        reveal(claim, in: app)
        capture(app, "02-cli-source-preview")
        claim.tap()
        XCTAssertTrue(app.navigationBars["Source notes"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Evidence: Inferred"].exists)
        XCTAssertTrue(app.staticTexts["Not executed"].exists)
        capture(app, "03-inferred-evidence-excerpt-and-limits")
        let firstSource = app.staticTexts["cmd/gen-docs/main.go"]
        reveal(firstSource, in: app); XCTAssertTrue(firstSource.isHittable)
        let secondSource = app.staticTexts["cmd/gh/main.go"]
        reveal(secondSource, in: app); XCTAssertTrue(secondSource.isHittable)
        let thirdSource = app.staticTexts["go.mod"]
        reveal(thirdSource, in: app); XCTAssertTrue(thirdSource.isHittable)
        capture(app, "04-all-additional-sources")
    }
    func testEmptyCollectionAndHTTPFailureAreActionable() {
        var app = launch("/empty")
        XCTAssertTrue(app.staticTexts["A quiet shelf"].waitForExistence(timeout: 10))
        capture(app, "05-empty-collection")
        app.terminate()
        app = launch("/unavailable")
        XCTAssertTrue(app.buttons["Try again"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "503")).firstMatch.exists)
        capture(app, "06-http-error-and-retry")
        app.buttons["Try again"].tap()
        XCTAssertTrue(app.buttons["Try again"].waitForExistence(timeout: 10))
    }
    func testMalformedJSONHasReadableError() {
        let app = launch("/malformed")
        XCTAssertTrue(app.buttons["Try again"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "could not be read")).firstMatch.exists)
        capture(app, "07-malformed-response")
    }
    func testLoadMoreKeepsEarlierRepositories() {
        let app = launch("/paginated")
        XCTAssertTrue(app.buttons["repo.cli/cli"].waitForExistence(timeout: 10))
        let more = app.buttons["feed.more"]
        reveal(more, in: app); XCTAssertTrue(more.isHittable); more.tap()
        let last = app.buttons["repo.rack/rack"]
        reveal(last, in: app); XCTAssertTrue(last.isHittable)
        capture(app, "08-paginated-collection")
        for _ in 0..<8 { if app.buttons["repo.cli/cli"].isHittable { break }; app.swipeDown() }
        XCTAssertTrue(app.buttons["repo.cli/cli"].exists)
    }
}
