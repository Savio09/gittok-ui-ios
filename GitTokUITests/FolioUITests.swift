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
        app.launchForReturningUser()
        XCTAssertTrue(app.tabBars.buttons["Saved"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Saved"].tap()
        XCTAssertTrue(app.staticTexts["Keep something good."].waitForExistence(timeout: 5))
        app.tabBars.buttons["You"].tap()
        XCTAssertTrue(app.buttons["interest.TypeScript"].waitForExistence(timeout: 5))
        app.buttons["interest.TypeScript"].tap()
        XCTAssertEqual(app.buttons["interest.TypeScript"].value as? String, "Selected")
        app.buttons["profile.for-you"].tap()
        XCTAssertTrue(app.buttons["feed.for-you"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Based on your interests")).firstMatch.exists)
    }
    func testSavedProjectSurvivesRestartAndOpensFreshPreview() {
        let app = application(server: "http://127.0.0.1:18580/gittok")
        app.launchForReturningUser()
        let bookmark = app.buttons["save.cli/cli"]
        XCTAssertTrue(bookmark.waitForExistence(timeout: 15))
        bookmark.tap()
        app.tabBars.buttons["Saved"].tap()
        XCTAssertTrue(app.buttons["saved.cli/cli"].waitForExistence(timeout: 5))
        app.terminate(); app.launchForReturningUser()
        app.tabBars.buttons["Saved"].tap()
        app.buttons["saved.cli/cli"].tap()
        XCTAssertTrue(app.staticTexts["Project preview"].waitForExistence(timeout: 10))
        let position = app.staticTexts["preview.position"]
        for _ in 0..<6 { if position.exists && position.frame.intersects(app.frame) { break }; app.swipeUp() }
        XCTAssertTrue(position.exists, app.debugDescription)
        XCTAssertEqual(app.buttons["save.cli/cli"].value as? String, "Saved")
        app.buttons["save.cli/cli"].tap()
        app.tabBars.buttons["Saved"].tap()
        XCTAssertTrue(app.staticTexts["Keep something good."].waitForExistence(timeout: 5))
    }
    func testFeedSourceShortcutLoadsActualEvidence() {
        let app = application(server: "http://127.0.0.1:18580/gittok")
        app.launchForReturningUser()
        let source = app.buttons["sources.cli/cli"]
        XCTAssertTrue(source.waitForExistence(timeout: 15))
        // XCTest may report a scrolled row as hittable while pinned chrome covers it.
        for _ in 0..<8 {
            let top = app.buttons["filter.All"].frame.maxY + 12
            let bottom = app.tabBars.firstMatch.frame.minY - 12
            if source.isHittable && source.frame.midY > top && source.frame.midY < bottom { break }
            let delta: CGFloat = source.frame.midY <= top ? 180 : -180
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.57))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: delta)))
        }
        source.tap()
        XCTAssertTrue(app.staticTexts["Evidence, not guesswork."].waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Evidence: Inferred"].exists)
        XCTAssertTrue(app.staticTexts["cmd/gen-docs/main.go"].exists)
    }
    func testVariableMediaPagesLoadImagesThroughHTTP() {
        let app = application(server: "http://127.0.0.1:18580/gittok/presentation")
        app.launchForReturningUser()
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
        app.launchForReturningUser(); app.buttons["search.open"].tap()
        let lookup = app.buttons["lookup.open"]
        for _ in 0..<6 { if lookup.isHittable { break }; app.swipeUp() }
        lookup.tap()
        let input = app.textFields["lookup.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5)); input.tap(); input.typeText("cli/cli")
        app.buttons["lookup.submit"].tap()
        XCTAssertTrue(app.buttons["preview.next"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["Saved"].exists)
        let skip = app.buttons["detail.skip"]
        for _ in 0..<12 { if skip.isHittable { break }; app.swipeUp() }
        skip.tap()
        XCTAssertTrue(app.tabBars.buttons["Discover"].isSelected)
        XCTAssertFalse(app.buttons["preview.next"].exists)
    }
    func testCurrentPageEvidencePausesPlaybackAndSelectsItsOwnClaim() {
        let app = application(server: "http://127.0.0.1:18580/gittok")
        app.launchForReturningUser()
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
        XCTAssertTrue(app.staticTexts["preview.reading-mode"].exists)
        XCTAssertFalse(app.buttons["preview.play"].exists)
        let source = app.buttons["preview.sources"]
        for _ in 0..<6 { if source.isHittable { break }; app.swipeDown() }
        source.tap()
        XCTAssertTrue(app.staticTexts["Declares github.com/spf13/cobra"].waitForExistence(timeout: 5))
        app.buttons["Close dialog"].tap()
        XCTAssertEqual(title.label, "Declared stack")
    }
    /// Explicit HTTP fixture verifies client presentation; no model or repository execution.
    func testAcceptedWalkthroughReplacesSourcePagesAndKeepsContextualEvidence() {
        let app = application(server: "http://127.0.0.1:18580/gittok/walkthrough")
        app.launchForReturningUser()
        let repo = app.buttons["repo.example/row-report"]
        XCTAssertTrue(repo.waitForExistence(timeout: 15)); repo.tap()
        let story = app.staticTexts["preview.story"]
        XCTAssertTrue(story.waitForExistence(timeout: 10))
        XCTAssertEqual(story.label, "This test project turns incoming rows into a report.")
        let counter = app.staticTexts["preview.position"]
        XCTAssertEqual(counter.label, "1 / 2")
        XCTAssertFalse(app.staticTexts["SOURCE OVERVIEW"].exists)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "preview.image").firstMatch.exists)
        var attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "walkthrough-accepted-purpose"; attachment.lifetime = .keepAlways; add(attachment)
        let next = app.buttons["preview.next"]
        for _ in 0..<6 { if next.isHittable { break }; app.swipeUp() }
        next.tap()
        XCTAssertEqual(counter.label, "2 / 2")
        XCTAssertEqual(app.staticTexts["preview.title"].label, "One workflow")
        XCTAssertEqual(story.label, "A caller passes rows to Summarize.\n\nSummarize aggregates the rows into totals.\n\nThe totals become the returned report.")
        attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "walkthrough-accepted-workflow"; attachment.lifetime = .keepAlways; add(attachment)
        XCTAssertTrue(app.staticTexts["preview.reading-mode"].exists)
        XCTAssertFalse(app.buttons["preview.play"].exists)
        let source = app.buttons["preview.sources"]
        for _ in 0..<6 { if source.isHittable { break }; app.swipeDown() }
        source.tap()
        XCTAssertTrue(app.staticTexts["A caller passes rows to Summarize."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["report.go"].exists)
        XCTAssertTrue(app.staticTexts["L2-2"].exists)
        XCTAssertTrue(app.staticTexts["Evidence: Inferred"].exists)
        XCTAssertTrue(app.staticTexts["Not executed"].exists)
        app.buttons["evidence.claim.2"].tap()
        XCTAssertTrue(app.staticTexts["Summarize aggregates the rows into totals."].exists)
        XCTAssertTrue(app.staticTexts["L3-3"].exists)
        app.buttons["evidence.claim.3"].tap()
        XCTAssertTrue(app.staticTexts["The totals become the returned report."].exists)
        XCTAssertTrue(app.staticTexts["L4-4"].exists)
        app.buttons["Close dialog"].tap()
        XCTAssertEqual(counter.label, "2 / 2")
        XCTAssertEqual(app.staticTexts["preview.title"].label, "One workflow")
    }

    func testBackgroundingAcceptedWalkthroughPreservesSelectedPage() {
        let app = application(server: "http://127.0.0.1:18580/gittok/walkthrough")
        app.launchForReturningUser()
        let repo = app.buttons["repo.example/row-report"]
        XCTAssertTrue(repo.waitForExistence(timeout: 15)); repo.tap()
        let story = app.staticTexts["preview.story"]
        XCTAssertTrue(story.waitForExistence(timeout: 10))
        let next = app.buttons["preview.next"]
        for _ in 0..<6 { if next.isHittable { break }; app.swipeUp() }
        next.tap()
        XCTAssertEqual(app.staticTexts["preview.position"].label, "2 / 2")
        let workflow = "A caller passes rows to Summarize.\n\nSummarize aggregates the rows into totals.\n\nThe totals become the returned report."
        XCTAssertEqual(story.label, workflow)
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(story.waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["preview.position"].label, "2 / 2")
        XCTAssertEqual(story.label, workflow)
        XCTAssertEqual(app.staticTexts["preview.title"].label, "One workflow")
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "walkthrough-foreground-retains-workflow"; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testFailedWalkthroughStatusAppearsBeforeSourcePreview() {
        let app = application(server: "http://127.0.0.1:18580/gittok/walkthrough-failed")
        app.launchForReturningUser()
        let card = app.buttons["repo.example/row-report"]
        XCTAssertTrue(card.waitForExistence(timeout: 15)); card.tap()
        let message = app.staticTexts["walkthrough.message"]
        XCTAssertTrue(message.waitForExistence(timeout: 10))
        XCTAssertTrue(message.isHittable, "Generation failure must be visible without scrolling past the source preview.")
        XCTAssertLessThan(message.frame.minY, app.staticTexts["preview.title"].frame.minY)
    }

}
