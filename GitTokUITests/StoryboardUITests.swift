import XCTest

/// Explicit HTTP fixture and manual narration events test the UI contract, not audible speech.
@MainActor final class StoryboardUITests: XCTestCase {
    private func launch(manual: Bool = true, unavailable: Bool = false, suite: String = UUID().uuidString) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["GITTOK_BASE_URL"] = "http://127.0.0.1:18580/gittok/visual-walkthrough"
        app.launchEnvironment["GITTOK_PREFERENCES_SUITE"] = "dev.gittok.storyboard.\(suite)"
        if unavailable { app.launchEnvironment["GITTOK_NARRATION_DRIVER"] = "unavailable" }
        else if manual { app.launchEnvironment["GITTOK_NARRATION_DRIVER"] = "manual" }
        app.launch()
        return app
    }
    private func open(_ app: XCUIApplication) {
        let repo = app.buttons["repo.example/row-report"]
        XCTAssertTrue(repo.waitForExistence(timeout: 15), "Start the explicit visual-walkthrough HTTP fixture.")
        repo.tap()
        XCTAssertTrue(app.staticTexts["storyboard.caption"].waitForExistence(timeout: 10))
    }
    private func reveal(_ element: XCUIElement, in app: XCUIApplication, up: Bool = true) {
        for _ in 0..<10 {
            if element.isHittable { return }
            if up { app.swipeUp() } else { app.swipeDown() }
        }
    }
    func testManualNarrationEventsControlCuePauseEvidenceAndReplay() {
        let app = launch(); open(app)
        let position = app.staticTexts["preview.position"]
        let firstPosition = position.label
        XCTAssertTrue(app.staticTexts["Manual narration test driver · no speech audio"].exists)
        XCTAssertEqual(app.buttons["preview.play"].label, "Play narration")
        reveal(app.buttons["preview.play"], in: app); app.buttons["preview.play"].tap()
        XCTAssertEqual(app.buttons["preview.play"].label, "Pause narration")
        let word = app.buttons["storyboard.test.word"]
        reveal(word, in: app); word.tap()
        XCTAssertFalse((app.staticTexts["storyboard.caption"].value as? String ?? "").isEmpty)
        let visual = app.staticTexts.matching(NSPredicate(format: "identifier == %@ AND label == %@", "storyboard.visual.concept", "THE IDEA")).element(boundBy: 0)
        for _ in 0..<24 {
            if visual.value as? String == "Cue reached" { break }
            word.tap()
        }
        XCTAssertEqual(visual.value as? String, "Cue reached", "The accepted literal cue reveals the visual from word events.")
        app.buttons["preview.play"].tap()
        XCTAssertEqual(app.buttons["preview.play"].label, "Resume narration")
        app.buttons["preview.play"].tap()
        app.buttons["storyboard.test.finish"].tap()
        XCTAssertNotEqual(position.label, firstPosition)
        let secondPosition = position.label
        app.buttons["storyboard.test.stale"].tap()
        XCTAssertEqual(position.label, secondPosition, "A completed old utterance cannot advance the new beat.")
        let source = app.buttons["preview.sources"]
        reveal(source, in: app, up: false); source.tap()
        XCTAssertTrue(app.staticTexts["Evidence, not guesswork."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Not executed"].exists)
        app.buttons["Close dialog"].tap()
        XCTAssertEqual(position.label, secondPosition)
        XCTAssertEqual(app.buttons["preview.play"].label, "Resume narration")
        reveal(app.buttons["preview.replay"], in: app); app.buttons["preview.replay"].tap()
        XCTAssertEqual(position.label, secondPosition)
        XCTAssertEqual(app.buttons["preview.play"].label, "Pause narration")
        XCUIDevice.shared.press(.home); app.activate()
        XCTAssertEqual(position.label, secondPosition)
        XCTAssertEqual(app.buttons["preview.play"].label, "Resume narration")
    }
    func testConcreteVisualsAndSavedStorySurviveReopen() {
        let app = launch(); open(app)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "storyboard.visual.concept").firstMatch.exists)
        var kinds: Set<String> = []
        let counter = app.staticTexts["preview.position"]
        let count = Int(counter.label.split(separator: "/").last?.trimmingCharacters(in: .whitespaces) ?? "") ?? 0
        XCTAssertGreaterThanOrEqual(count, 6)
        for _ in 0..<count {
            for kind in ["concept", "terminal", "flow", "comparison", "source"] {
                if app.descendants(matching: .any).matching(identifier: "storyboard.visual.\(kind)").firstMatch.exists { kinds.insert(kind) }
            }
            let next = app.buttons["preview.next"]
            if next.isEnabled { reveal(next, in: app); next.tap() }
        }
        XCTAssertEqual(kinds, ["concept", "terminal", "flow", "comparison", "source"])
        XCTAssertFalse(app.staticTexts["Verified setup"].exists)
        let save = app.buttons["save.example/row-report"]
        reveal(save, in: app, up: false); save.tap()
        app.terminate(); app.launch(); app.buttons["nav.saved"].tap()
        let saved = app.buttons["saved.example/row-report"]
        XCTAssertTrue(saved.waitForExistence(timeout: 5)); saved.tap()
        XCTAssertTrue(app.staticTexts["storyboard.caption"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "storyboard.visual.concept").firstMatch.exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "folio-native-visual-walkthrough"; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testInjectedUnavailableVoiceKeepsReadableManualNavigation() {
        let app = launch(unavailable: true); open(app)
        XCTAssertTrue(app.staticTexts["storyboard.unavailable"].exists)
        XCTAssertFalse(app.buttons["preview.play"].isEnabled)
        XCTAssertTrue(app.staticTexts["Rows of data"].exists)
        let next = app.buttons["preview.next"]
        reveal(next, in: app); next.tap()
        XCTAssertEqual(app.staticTexts["preview.position"].label, "2 / 6")
        XCTAssertTrue(app.staticTexts["storyboard.caption"].exists)
    }
    /// Real AVSpeechSynthesizer callbacks, separate from the deterministic event tests.
    func testNativeSpeechProducesWordCallbacks() throws {
        let app = launch(manual: false); open(app)
        if app.staticTexts["storyboard.unavailable"].exists {
            throw XCTSkip("No native simulator voice is installed; readable fallback is active.")
        }
        XCTAssertFalse(app.buttons["storyboard.test.word"].exists)
        let play = app.buttons["preview.play"]
        reveal(play, in: app); play.tap()
        let caption = app.staticTexts["storyboard.caption"]
        let spokenWord = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            !(caption.value as? String ?? "").isEmpty
        }, object: caption)
        XCTAssertEqual(XCTWaiter.wait(for: [spokenWord], timeout: 15), .completed, "Native voice must deliver real word callbacks.")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "folio-real-native-speech-word-callback"; attachment.lifetime = .keepAlways; add(attachment)
        if app.buttons["preview.play"].label == "Pause narration" { app.buttons["preview.play"].tap() }
        XCTAssertEqual(app.buttons["preview.play"].label, "Resume narration")
    }

    /// Opt-in only: the coordinator must prepare and authorize this backend job first.
    func testOptInPreparedLiveRepositoryThroughLookupSpeechSaveAndEvidence() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let repository = environment["GITTOK_LIVE_REPOSITORY"], !repository.isEmpty,
              let baseURL = environment["GITTOK_LIVE_BASE_URL"], !baseURL.isEmpty else {
            throw XCTSkip("Set both GITTOK_LIVE_REPOSITORY and GITTOK_LIVE_BASE_URL for an authorized prepared-backend smoke test.")
        }
        guard repository.split(separator: "/").count == 2 else { XCTFail("Use an explicit owner/repository."); return }
        let app = XCUIApplication()
        app.launchEnvironment["GITTOK_BASE_URL"] = baseURL
        app.launchEnvironment["GITTOK_PREFERENCES_SUITE"] = "dev.gittok.live-storyboard.\(UUID().uuidString)"
        app.launchEnvironment["GITTOK_NARRATION_DRIVER"] = "native"
        app.launch()
        XCTAssertTrue(app.buttons["nav.profile"].waitForExistence(timeout: 10)); app.buttons["nav.profile"].tap()
        let lookup = app.buttons["profile.lookup"]
        reveal(lookup, in: app); lookup.tap()
        let input = app.textFields["lookup.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5)); input.tap(); input.typeText(repository)
        app.buttons["lookup.submit"].tap()
        let caption = app.staticTexts["storyboard.caption"]
        XCTAssertTrue(caption.waitForExistence(timeout: 45), "The prepared backend must return a valid complete storyboard.")
        let firstNarration = caption.label
        XCTAssertFalse(firstNarration.isEmpty)
        XCTAssertTrue(["concept", "terminal", "flow", "comparison", "source"].contains { kind in
            app.descendants(matching: .any).matching(identifier: "storyboard.visual.\(kind)").firstMatch.exists
        })
        XCTAssertFalse(app.buttons["storyboard.test.word"].exists)
        if !app.staticTexts["storyboard.unavailable"].exists {
            let play = app.buttons["preview.play"]
            reveal(play, in: app); play.tap()
            let word = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                !(caption.value as? String ?? "").isEmpty
            }, object: caption)
            XCTAssertEqual(XCTWaiter.wait(for: [word], timeout: 15), .completed, "Expect actual native speech callbacks.")
            if play.label == "Pause narration" { play.tap() }
        } else {
            let note = XCTAttachment(string: "No native voice is installed; verified readable fallback instead of speech callbacks.")
            note.lifetime = .keepAlways; add(note)
        }
        let save = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "save.")).firstMatch
        reveal(save, in: app, up: false); XCTAssertTrue(save.isHittable); save.tap()
        XCTAssertEqual(save.value as? String, "Saved")
        app.terminate(); app.launch(); app.buttons["nav.saved"].tap()
        let saved = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "saved.")).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 10)); saved.tap()
        XCTAssertTrue(caption.waitForExistence(timeout: 45))
        XCTAssertEqual(caption.label, firstNarration, "Online reopening preserves the prepared accepted story.")
        let source = app.buttons["preview.sources"]
        reveal(source, in: app); source.tap()
        XCTAssertTrue(app.staticTexts["Evidence, not guesswork."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Not executed"].exists)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "evidence.path.0").firstMatch.exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "folio-opt-in-prepared-live-repository-evidence"; attachment.lifetime = .keepAlways; add(attachment)
    }

}
