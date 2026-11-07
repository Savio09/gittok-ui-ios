import XCTest
@testable import GitTokCore

final class StoryboardTests: XCTestCase {
    private func claim(_ id: String = "statement-1", visual: [String: Any]? = nil) -> [String: Any] {
        ["id": id, "label": "A source fact", "source": ["ref": "render.go", "lines": "4-6"],
         "additional_sources": [["ref": "README.md", "lines": "1-2"]], "excerpt": "render(input)",
         "explanation": "Inspected renderer", "supports": "📄 It reads Markdown, then renders the text.",
         "limit": "Source inspection only", "evidence_status": "inferred",
         "visual": visual ?? ["kind": "flow", "title": "Render the document", "lines": ["Read Markdown", "Render text", "Write output"], "focus": 2, "cue": "renders"]]
    }
    private func section(_ index: Int = 1) -> [String: Any] {
        ["id": "scene-\(index)", "kind": index == 1 ? "how" : "handoff", "title": "Scene \(index)",
         "body": "Actual narrated source explanation", "evidence_mode": "not_executed", "claims": [claim("statement-\(index)")],
         "storyboard": ["version": 1, "beats": [["id": "beat-\(index)", "claim_id": "statement-\(index)"]]]]
    }
    private func preview(_ sections: [[String: Any]], extra: [String: Any] = [:], omitting: [String] = []) throws -> RepoPreview {
        let base: [String: Any] = ["id": "o/r", "owner": "o", "name": "r", "slug": "o/r", "kind": "cli",
                                  "description": "A provider description", "github_url": "https://github.com/o/r", "presentation": "walkthrough", "evidence_mode": "not_executed", "sections": sections]
        var object = base.merging(extra) { _, value in value }
        for key in omitting { object.removeValue(forKey: key) }
        return try Wire.decoder().decode(RepoPreview.self, from: JSONSerialization.data(withJSONObject: object))
    }
    func testProducerVisualAndStoryboardSurviveCodableSnapshot() throws {
        let repo = try preview([section()])
        let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(repo)) as! [String: Any]
        let section = try XCTUnwrap((encoded["sections"] as? [[String: Any]])?.first)
        let visual = (section["claims"] as? [[String: Any]])?.first?["visual"] as? [String: Any]
        XCTAssertEqual(visual?["lines"] as? [String], ["Read Markdown", "Render text", "Write output"])
        XCTAssertNotNil(section["storyboard"])
    }
    func testStoryboardFieldsDoNotPromoteReportsWithoutAcceptedPresentation() throws {
        // Empty description isolates the presentation check from synthetic-page fallback.
        XCTAssertNotNil(try preview([section()], extra: ["description": ""]).storyboardBeats)
        let missing = try preview([section()], extra: ["description": ""], omitting: ["presentation"])
        let unknown = try preview([section()], extra: ["description": "", "presentation": "future_report"])
        for repo in [missing, unknown] {
            XCTAssertNil(repo.storyboardBeats)
            XCTAssertEqual(repo.previewPages.count, 1)
            XCTAssertEqual(repo.evidenceEntries.first?.claim.source.ref, "render.go")
        }
    }
    func testFilmsRequireExplicitSourceInspectionModeOnRepoAndEveryPage() throws {
        var reports = [try preview([section()], omitting: ["evidence_mode"])]
        for mode in ["unknown", "observed_running"] {
            reports.append(try preview([section()], extra: ["evidence_mode": mode]))
        }
        var missingPageMode = section(); missingPageMode.removeValue(forKey: "evidence_mode")
        reports.append(try preview([missingPageMode]))
        for mode in ["unknown", "observed_running"] {
            var page = section(); page["evidence_mode"] = mode
            reports.append(try preview([page]))
        }
        for repo in reports {
            XCTAssertNil(repo.storyboardBeats)
            XCTAssertEqual(repo.previewPages.first?.body, "Actual narrated source explanation")
            XCTAssertEqual(repo.evidenceEntries.count, 1)
        }
        XCTAssertNotNil(try preview([section()]).storyboardBeats)
    }
    func testVariableSceneCountsResolveEveryClaimAndEvidenceInOrder() throws {
        for count in [1, 2, 12] {
            let repo = try preview((1...count).map(section))
            let beats = try XCTUnwrap(repo.storyboardBeats)
            XCTAssertEqual(beats.map(\.id), (1...count).map { "beat-\($0)" })
            XCTAssertEqual(beats.map(\.claim.id), (1...count).map { "statement-\($0)" })
            XCTAssertEqual(beats.map(\.evidenceID), repo.evidenceEntries.map(\.id))
            XCTAssertEqual(beats.map(\.sceneID), repo.previewPages.map(\.id))
            XCTAssertEqual(beats.map(\.sceneTitle), repo.previewPages.map(\.title))
            XCTAssertEqual(beats.first?.narration, "📄 It reads Markdown, then renders the text.")
            XCTAssertEqual(beats.first?.visual.focus, 2)
            XCTAssertEqual(repo.previewPages.first?.storyboard?.version, 1)
        }
    }
    func testUnicodeCueUsesFirstLiteralUTF16PositionAndSpeechRangeProgress() throws {
        var source = section()
        var fact = claim()
        let text = "👩🏽‍💻 Cafe\u{301} renders then renders again."
        fact["supports"] = text
        source["claims"] = [fact]
        let beat = try XCTUnwrap(try preview([source]).storyboardBeats?.first)
        let offset = (text as NSString).range(of: "renders").location
        XCTAssertEqual(beat.cueUTF16Offset, offset)
        XCTAssertFalse(beat.shouldRevealVisual(for: NSRange(location: 0, length: offset)))
        XCTAssertTrue(beat.shouldRevealVisual(for: NSRange(location: offset, length: 7)))
        XCTAssertTrue(beat.shouldRevealVisual(for: NSRange(location: offset + 8, length: 1)))
        for range in [NSRange(location: NSNotFound, length: 1), NSRange(location: -1, length: 1), NSRange(location: 0, length: 0), NSRange(location: 1, length: Int.max)] {
            XCTAssertFalse(beat.shouldRevealVisual(for: range))
        }
    }
    func testMissingUnknownAndMalformedAdditionsKeepReadablePages() throws {
        for broken: Any in [NSNull(), "future", ["version": 2, "beats": []], ["version": 1, "beats": "broken"]] {
            var source = section(); source["storyboard"] = broken
            let repo = try preview([source])
            XCTAssertNil(repo.storyboardBeats)
            XCTAssertEqual(repo.previewPages.first?.body, "Actual narrated source explanation")
            XCTAssertEqual(repo.evidenceEntries.count, 1)
        }
        for broken: Any in [NSNull(), "future", ["kind": "flow", "focus": "broken"]] {
            var source = section(); var fact = claim(); fact["visual"] = broken; source["claims"] = [fact]
            let repo = try preview([source])
            XCTAssertNil(repo.storyboardBeats)
            XCTAssertEqual(repo.previewPages.count, 1)
        }
    }
    func testInvalidVisualKindsBoundsAndCuesInvalidateWholeFilm() throws {
        let good: [String: Any] = ["kind": "flow", "title": "Render", "lines": ["Input", "Output"], "focus": 1, "cue": "renders"]
        let changes: [[String: Any]] = [
            ["kind": "future"], ["title": String(repeating: "x", count: 57)], ["lines": ["Only one"]],
            ["lines": ["One", "Two", "Three", "Four", "Five"]], ["lines": ["Input", String(repeating: "x", count: 81)]],
            ["lines": ["Input", "Output\nInjected"]], ["focus": -1], ["focus": 3], ["cue": ""], ["cue": "missing"],
            ["cue": String(repeating: "x", count: 41)], ["kind": "comparison", "lines": ["A", "B", "C"]],
            ["kind": "concept", "lines": []]
        ]
        for change in changes {
            var source = section(2); source["claims"] = [claim("statement-2", visual: good.merging(change) { _, value in value })]
            let repo = try preview([section(), source])
            XCTAssertNil(repo.storyboardBeats, "Must fall back for \(change)")
            XCTAssertEqual(repo.previewPages.count, 2)
        }
    }
    func testNonSourceVisualTextAndCuesMatchProducerNonblankControlRules() throws {
        let good: [String: Any] = ["kind": "flow", "title": "Render", "lines": ["Input", "Output"], "focus": 1, "cue": "renders"]
        let changes: [[String: Any]] = [["title": ""], ["title": " \u{00a0} "], ["lines": ["", "Output"]],
                                      ["lines": ["Input", " \u{2003} "]], ["cue": " "], ["cue": "\n"], ["cue": "\t"]]
        for change in changes {
            var page = section()
            var fact = claim(visual: good.merging(change) { _, value in value })
            fact["supports"] = "It renders text.\n\tInput becomes output."
            page["claims"] = [fact]
            let repo = try preview([page])
            XCTAssertTrue(repo.storyboardBeats == nil, "Invalid visual text must fall back: \(change)")
            XCTAssertEqual(repo.previewPages.count, 1)
        }
        // Go rejects Unicode controls (Cc), while format scalars such as the
        // emoji joiner remain valid reviewed visual wording.
        var page = section()
        var fact = claim(visual: good.merging(["title": "👩🏽‍💻 Render", "lines": ["👩🏽‍💻 Input", "Output"], "cue": "👩🏽‍💻"]) { _, value in value })
        fact["supports"] = "👩🏽‍💻 It renders text."
        page["claims"] = [fact]
        XCTAssertNotNil(try preview([page]).storyboardBeats)
    }
    func testSectionMediaCannotBeDroppedByPromotingItsStoryboardToFilm() throws {
        var page = section()
        page["media"] = ["kind": "image", "url": "https://example.com/capture.png", "evidence_mode": "observed_running"]
        let repo = try preview([page])
        XCTAssertTrue(repo.storyboardBeats == nil)
        XCTAssertEqual(repo.previewPages.first?.media?.url, "https://example.com/capture.png")
        XCTAssertEqual(repo.previewPages.first?.media?.evidenceMode, "observed_running")
        XCTAssertEqual(repo.evidenceEntries.count, 1)
    }
    func testDanglingCrossSectionDuplicateAndOutOfOrderReferencesInvalidateWholeFilm() throws {
        for beats in [
            [["id": "beat-2", "claim_id": "missing"]],
            [["id": "beat-2", "claim_id": "statement-1"]],
            [["id": "beat-1", "claim_id": "statement-2"]],
            [["id": "a", "claim_id": "statement-2"], ["id": "b", "claim_id": "statement-2"]],
            [["id": "", "claim_id": "statement-2"]], []
        ] {
            var source = section(2); source["storyboard"] = ["version": 1, "beats": beats]
            XCTAssertNil(try preview([section(), source]).storyboardBeats)
        }
        var source = section()
        source["claims"] = [claim("statement-1"), claim("statement-2")]
        source["storyboard"] = ["version": 1, "beats": [["id": "b", "claim_id": "statement-2"], ["id": "a", "claim_id": "statement-1"]]]
        XCTAssertNil(try preview([source]).storyboardBeats)
    }
    func testPartialFilmsCannotDropUnreadableOrUnreferencedScenes() throws {
        var missing = section(2); missing.removeValue(forKey: "storyboard")
        XCTAssertNil(try preview([section(), missing]).storyboardBeats)
        var omitted = section(); omitted["claims"] = [claim(), claim("unreferenced")]
        XCTAssertNil(try preview([omitted]).storyboardBeats)
        XCTAssertNil(try preview([section()], extra: ["media": ["kind": "image"]]).storyboardBeats)
        XCTAssertNil(try preview([]).storyboardBeats)
    }
    func testHandoffIsPreviewContentWithoutBecomingSetupEvidence() throws {
        let repo = try preview([section(), section(2)])
        XCTAssertEqual(repo.storyboardBeats?.last?.sceneKind, "handoff")
        XCTAssertEqual(repo.previewPages.last?.kind, "handoff")
        XCTAssertNil(repo.setupSection)
    }
    func testFallbackContentIdentitiesIncludeVisualAndStoryboardFacts() throws {
        var original = section(); original.removeValue(forKey: "id")
        var fact = claim(); fact.removeValue(forKey: "id"); original["claims"] = [fact]
        let before = try preview([original])
        var edited = original
        var changed = fact; var visual = changed["visual"] as! [String: Any]; visual["focus"] = 3; changed["visual"] = visual
        edited["claims"] = [changed]
        let afterVisual = try preview([edited])
        XCTAssertNotEqual(before.previewPages.first?.id, afterVisual.previewPages.first?.id)
        XCTAssertNotEqual(before.evidenceEntries.first?.id, afterVisual.evidenceEntries.first?.id)
        edited = original; edited["storyboard"] = ["version": 1, "beats": [["id": "revised-beat", "claim_id": "statement-1"]]]
        XCTAssertNotEqual(before.previewPages.first?.id, try preview([edited]).previewPages.first?.id)
    }
    func testSourceVisualPreservesActualLongPathAndSixOriginalCodeLines() throws {
        let path = String(repeating: "nested/", count: 12) + "render.go"
        let lines = ["\tfunc render() {", String(repeating: "x", count: 90), "  first()", "  second()", "  third()", "}"]
        var source = section(); var fact = claim()
        fact["source"] = ["ref": path]; fact["excerpt"] = lines.joined(separator: "\n") + "\nignored seventh line"
        fact["visual"] = ["kind": "source", "title": path, "lines": lines, "focus": 6, "cue": "renders"]
        source["claims"] = [fact]
        let repo = try preview([source])
        XCTAssertEqual(repo.storyboardBeats?.first?.visual.lines, lines)
        var forged = fact; forged["visual"] = ["kind": "source", "title": path, "lines": ["invented()"], "focus": 1, "cue": "renders"]
        source["claims"] = [forged]
        XCTAssertNil(try preview([source]).storyboardBeats)
    }
    @MainActor func testSavedReopenedFilmRetainsNestedVisualsNarrationAndSources() throws {
        let defaults = UserDefaults(suiteName: "gittok.storyboard-tests.\(UUID().uuidString)")!
        let preferences = DiscoveryPreferences(defaults: defaults)
        preferences.toggleSaved(try preview([section(), section(2)]))
        let reopened = try XCTUnwrap(DiscoveryPreferences(defaults: defaults).saved.first)
        let beat = try XCTUnwrap(reopened.storyboardBeats?.last)
        XCTAssertEqual(reopened.storyboardBeats?.count, 2)
        XCTAssertEqual(beat.visual.lines, ["Read Markdown", "Render text", "Write output"])
        XCTAssertEqual(beat.claim.allSources.map(\.ref), ["render.go", "README.md"])
        XCTAssertEqual(beat.claim.limit, "Source inspection only")
        XCTAssertEqual(beat.claim.excerpt, "render(input)")
        XCTAssertEqual(beat.claim.status, .inferred)
    }
}
