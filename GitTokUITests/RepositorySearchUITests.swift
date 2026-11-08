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

@MainActor final class RepositorySearchLiveUITests: XCTestCase {
    func testRealPublicMetadataSearchOutsideDiscover() throws {
        guard ProcessInfo.processInfo.environment["GITTOK_LIVE_SEARCH"] == "1" else { throw XCTSkip("Opt-in live metadata search; no walkthrough generation") }
        let app = XCUIApplication()
        app.launchEnvironment["GITTOK_BASE_URL"] = ProcessInfo.processInfo.environment["GITTOK_LIVE_SEARCH_BASE_URL"] ?? "http://127.0.0.1:18082"
        app.launchEnvironment["GITTOK_PREFERENCES_SUITE"] = "dev.gittok.live-search.\(UUID().uuidString)"
        app.launchForReturningUser()
        XCTAssertTrue(app.buttons["search.open"].waitForExistence(timeout: 15)); app.buttons["search.open"].tap()
        let input = app.textFields["feed.search"]
        XCTAssertTrue(input.waitForExistence(timeout: 5)); input.tap(); input.typeText("excalidraw\n")
        XCTAssertTrue(app.buttons["search.excalidraw/excalidraw"].waitForExistence(timeout: 25))
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "actual-github-search-excalidraw"; attachment.lifetime = .keepAlways; add(attachment)
        app.buttons["search.clear"].tap()
        input.tap(); input.typeText("pocketbase/pocketbase\n")
        XCTAssertTrue(app.buttons["search.pocketbase/pocketbase"].waitForExistence(timeout: 25))
        let exact = XCTAttachment(screenshot: app.screenshot()); exact.name = "actual-github-search-exact-repository"; exact.lifetime = .keepAlways; add(exact)
        // Do not open either preview: this acceptance run exercises metadata only.
    }
}
