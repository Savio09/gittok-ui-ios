import XCTest

@MainActor final class RepositorySearchUITests: XCTestCase {
    private func openSearch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["GITTOK_BASE_URL"] = "http://127.0.0.1:18580/gittok"
        app.launchEnvironment["GITTOK_PREFERENCES_SUITE"] = "dev.gittok.search-tests.\(UUID().uuidString)"
        app.launchForReturningUser()
        XCTAssertTrue(app.buttons["repo.cli/cli"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["repo.example/unlisted-project"].exists)
        app.buttons["search.open"].tap()
        XCTAssertTrue(app.textFields["feed.search"].waitForExistence(timeout: 5))
        return app
    }
    private func search(_ query: String, in app: XCUIApplication) {
        let field = app.textFields["feed.search"]
        field.tap(); field.typeText(query + "\n")
    }
    func testSearchFindsProjectOutsideDiscoverAndOpensItsOwnPreview() {
        let app = openSearch()
        search("unlisted", in: app)
        let result = app.buttons["search.example/unlisted-project"]
        XCTAssertTrue(result.waitForExistence(timeout: 15))
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "remote-search-outside-feed"; attachment.lifetime = .keepAlways; add(attachment)
        result.tap()
        XCTAssertTrue(app.staticTexts["Project preview"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Outside the feed"].waitForExistence(timeout: 10))
    }
    func testSearchFailureIsDistinctFromEmptyAndCanBeCleared() {
        let app = openSearch()
        search("offline", in: app)
        XCTAssertTrue(app.staticTexts["search.error"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["search.empty"].exists)
        app.buttons["search.clear"].tap()
        search("nothing", in: app)
        XCTAssertTrue(app.staticTexts["search.empty"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["search.error"].exists)
    }
    func testSearchRetryAndPaginationKeepResultsIndependentOfFeed() {
        let app = openSearch()
        search("retry-\(UUID().uuidString)", in: app)
        XCTAssertTrue(app.buttons["search.retry"].waitForExistence(timeout: 10))
        app.buttons["search.retry"].tap()
        XCTAssertTrue(app.buttons["search.example/unlisted-project"].waitForExistence(timeout: 10))
        let more = app.buttons["search.more"]
        for _ in 0..<5 { if more.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(more.isHittable); more.tap()
        XCTAssertTrue(app.buttons["search.example/another-project"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons.matching(identifier: "search.example/unlisted-project").count, 1)
    }
    func testEmptyKeyboardSubmissionDoesNotStartLoading() {
        let app = openSearch()
        app.textFields["feed.search"].typeText("\n")
        XCTAssertFalse(app.progressIndicators["search.loading"].exists)
        XCTAssertFalse(app.staticTexts["search.empty"].exists)
    }
}
