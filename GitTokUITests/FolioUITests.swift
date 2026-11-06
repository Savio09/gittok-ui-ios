import XCTest

@MainActor final class FolioUITests: XCTestCase {
    private func application(server: String = "http://localhost:1", suite: String = UUID().uuidString) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["GITTOK_BASE_URL"] = server
        app.launchEnvironment["GITTOK_PREFERENCES_SUITE"] = "dev.gittok.uitests.\(suite)"
        return app
    }
    func testFolioNavigationAndInterests() {
        let app = application()
        app.launch()
        XCTAssertTrue(app.buttons["nav.saved"].waitForExistence(timeout: 10))
        app.buttons["nav.saved"].tap()
        XCTAssertTrue(app.staticTexts["Keep something good."].waitForExistence(timeout: 5))
        app.buttons["nav.profile"].tap()
        XCTAssertTrue(app.buttons["interest.TypeScript"].waitForExistence(timeout: 5))
        app.buttons["interest.TypeScript"].tap()
        XCTAssertEqual(app.buttons["interest.TypeScript"].value as? String, "Selected")
        app.buttons["profile.for-you"].tap()
        XCTAssertTrue(app.buttons["feed.for-you"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Based on your interests")).firstMatch.exists)
    }
    func testSavedProjectSurvivesRestartAndOpensFreshPreview() {
        let app = application(server: "http://127.0.0.1:18580/gittok")
        app.launch()
        let bookmark = app.buttons["save.cli/cli"]
        XCTAssertTrue(bookmark.waitForExistence(timeout: 15))
        bookmark.tap()
        app.buttons["nav.saved"].tap()
        XCTAssertTrue(app.buttons["saved.cli/cli"].waitForExistence(timeout: 5))
        app.terminate(); app.launch()
        app.buttons["nav.saved"].tap()
        app.buttons["saved.cli/cli"].tap()
        XCTAssertTrue(app.staticTexts["Project preview"].waitForExistence(timeout: 10))
        let position = app.staticTexts["preview.position"]
        for _ in 0..<6 { if position.exists && position.frame.intersects(app.frame) { break }; app.swipeUp() }
        XCTAssertTrue(position.exists, app.debugDescription)
        XCTAssertEqual(app.buttons["save.cli/cli"].value as? String, "Saved")
        app.buttons["save.cli/cli"].tap()
        app.buttons["nav.saved"].tap()
        XCTAssertTrue(app.staticTexts["Keep something good."].waitForExistence(timeout: 5))
    }
    func testFeedSourceShortcutLoadsActualEvidence() {
        let app = application(server: "http://127.0.0.1:18580/gittok")
        app.launch()
        let source = app.buttons["sources.cli/cli"]
        XCTAssertTrue(source.waitForExistence(timeout: 15))
        for _ in 0..<5 { if source.isHittable { break }; app.swipeUp() }
        source.tap()
        XCTAssertTrue(app.staticTexts["Evidence, not guesswork."].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Evidence: Inferred"].exists)
        XCTAssertTrue(app.staticTexts["cmd/gen-docs/main.go"].exists)
    }
    func testVariableMediaPagesLoadImagesThroughHTTP() {
        let app = application(server: "http://127.0.0.1:18580/gittok/presentation")
        app.launch()
        let repo = app.buttons["repo.cli/cli"]
        XCTAssertTrue(repo.waitForExistence(timeout: 15)); repo.tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "preview.image").firstMatch.waitForExistence(timeout: 10))
        let counter = app.staticTexts["preview.position"]
        let parts = counter.label.split(separator: "/").map { $0.trimmingCharacters(in: .whitespaces) }
        XCTAssertGreaterThanOrEqual(Int(parts.last ?? "") ?? 0, 5)
        for _ in 0..<4 {
            let next = app.buttons["preview.next"]
            for _ in 0..<5 { if next.isHittable { break }; app.swipeUp() }
            next.tap()
        }
        XCTAssertTrue(counter.label.hasPrefix("5 /"))
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "folio-variable-media-pages"; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testLookupRetainsSharedNavigationAndSkipReturnsToDiscover() {
        let app = application(server: "http://127.0.0.1:18580/gittok")
        app.launch(); app.buttons["search.open"].tap()
        let lookup = app.buttons["lookup.open"]
        for _ in 0..<6 { if lookup.isHittable { break }; app.swipeUp() }
        lookup.tap()
        let input = app.textFields["lookup.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5)); input.tap(); input.typeText("cli/cli")
        app.buttons["lookup.submit"].tap()
        XCTAssertTrue(app.buttons["preview.next"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["nav.saved"].exists)
        let skip = app.buttons["detail.skip"]
        for _ in 0..<12 { if skip.isHittable { break }; app.swipeUp() }
        skip.tap()
        XCTAssertEqual(app.buttons["nav.discover"].value as? String, "Selected")
        XCTAssertFalse(app.buttons["preview.next"].exists)
    }
    func testCurrentPageEvidencePausesPlaybackAndSelectsItsOwnClaim() {
        let app = application(server: "http://127.0.0.1:18580/gittok")
        app.launch()
        let repo = app.buttons["repo.cli/cli"]
        XCTAssertTrue(repo.waitForExistence(timeout: 15)); repo.tap()
        let title = app.staticTexts["preview.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        for _ in 0..<6 {
            if title.label == "Declared stack" { break }
            let next = app.buttons["preview.next"]
            for _ in 0..<6 { if next.isHittable { break }; app.swipeUp() }
            next.tap()
        }
        XCTAssertEqual(title.label, "Declared stack")
        let play = app.buttons["preview.play"]
        for _ in 0..<6 { if play.isHittable { break }; app.swipeUp() }
        play.tap()
        let source = app.buttons["preview.sources"]
        for _ in 0..<6 { if source.isHittable { break }; app.swipeDown() }
        source.tap()
        XCTAssertTrue(app.staticTexts["Declares github.com/spf13/cobra"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 5.5)
        app.buttons["Close dialog"].tap()
        XCTAssertEqual(title.label, "Declared stack")
    }
}
