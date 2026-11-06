import XCTest
@testable import GitTokCore

final class PreviewContentTests: XCTestCase {
    private func preview(_ fields: [String: Any]) throws -> RepoPreview {
        let base: [String: Any] = ["id":"o/r", "owner":"o", "name":"r", "slug":"o/r", "kind":"other", "description":"", "github_url":"https://github.com/o/r"]
        return try Wire.decoder().decode(RepoPreview.self, from: JSONSerialization.data(withJSONObject: base.merging(fields) { _, new in new }))
    }
    func testZeroOneAndManyPreviewPagesFollowActualContent() throws {
        XCTAssertTrue(try preview([:]).previewPages.isEmpty)
        XCTAssertEqual(try preview(["description":"Actual provider description"]).previewPages.count, 1)
        let sections = (0..<12).map { ["kind":"how", "title":"Capture \($0)", "media":["kind":"image", "url":"https://example.com/\($0).png", "evidence_mode":"observed_running"]] as [String: Any] }
        let repo = try preview(["sections":sections])
        XCTAssertEqual(repo.previewPages.count, 12)
        XCTAssertEqual(repo.previewPages.map(\.title), (0..<12).map { "Capture \($0)" })
        XCTAssertEqual(Set(repo.previewPages.map(\.id)).count, 12)
    }
    func testMediaExecutionDoesNotPromoteSourceClaims() throws {
        let claim: [String: Any] = ["label":"Declared function", "source":["ref":"main.go"], "explanation":"A source declaration"]
        let repo = try preview(["evidence_mode":"observed_running", "media":["kind":"video", "url":"https://example.com/demo.mp4", "evidence_mode":"observed_running"], "sections":[["kind":"how", "title":"Source", "claims":[claim]]]])
        XCTAssertEqual(repo.previewPages.first?.media?.evidenceMode, "observed_running")
        XCTAssertNil(repo.previewPages.first?.evidenceMode)
        XCTAssertNil(repo.previewPages.last?.evidenceMode)
        XCTAssertNil(repo.evidenceEntries.first?.evidenceMode)
    }
    func testMissingMediaModeRemainsUnknownEvenWhenSectionIsObserved() throws {
        let repo = try preview(["sections":[["kind":"how", "title":"Capture", "evidence_mode":"observed_running", "media":["kind":"image", "url":"https://example.com/shot.png"]]]])
        XCTAssertEqual(repo.previewPages.first?.evidenceMode, "observed_running")
        XCTAssertNil(repo.previewPages.first?.media?.evidenceMode)
        XCTAssertEqual(ExecutionEvidence.label(for: repo.previewPages.first?.media?.evidenceMode), "Execution unknown")
    }
    func testDuplicateClaimLabelsRemainIndependentlySelectable() throws {
        let claims = ["a/package.json", "b/package.json"].map { ["label":"Declares command build", "source":["ref":$0, "lines":"6"], "explanation":$0] as [String: Any] }
        let repo = try preview(["sections":[["kind":"setup", "title":"Commands", "claims":claims]]])
        XCTAssertEqual(repo.evidenceEntries.count, 2)
        XCTAssertNotEqual(repo.evidenceEntries[0].id, repo.evidenceEntries[1].id)
        XCTAssertEqual(repo.evidenceEntries[1].claim.source.ref, "b/package.json")
    }
    func testOptionalMediaFitAndSignalsRoundTripWithoutLosingSources() throws {
        let repo = try preview(["media":["kind":"image", "url":"https://example.com/shot.png"], "fit":["summary":"Provider fit", "dimensions":[["name":"Setup", "level":2, "word":"Some setup"]]], "signals":[["value":"Go", "reason":"you_know"]]])
        let saved = try JSONDecoder().decode(RepoPreview.self, from: JSONEncoder().encode(repo))
        XCTAssertEqual(saved.media?.url, "https://example.com/shot.png")
        XCTAssertEqual(saved.fit?.summary, "Provider fit")
        XCTAssertEqual(saved.signals?.first?.value, "Go")
    }
    func testUnknownArtifactKindAndUnsafeURLHaveConservativeRendering() throws {
        let repo = try preview(["media":["kind":"future_format", "url":"javascript:alert(1)"]])
        XCTAssertEqual(repo.media?.renderingKind, .unsupported)
        XCTAssertNil(repo.media?.safeURL)
        XCTAssertEqual(repo.previewPages.count, 1)
    }
    func testMixedCaptureAndSourceSectionRetainsIndependentSourceMode() throws {
        let section: [String: Any] = ["kind":"how", "title":"How", "body":"A source explanation", "evidence_mode":"not_executed", "media":["kind":"image", "url":"https://example.com/capture.png", "evidence_mode":"observed_running"]]
        let repo = try preview(["sections":[section]])
        XCTAssertEqual(repo.previewPages.first?.evidenceMode, "not_executed")
        XCTAssertEqual(repo.previewPages.first?.media?.evidenceMode, "observed_running")
    }
    func testInsertingContentDoesNotReassignExistingPageOrClaimIdentity() throws {
        func section(_ name: String) -> [String: Any] {
            ["kind":"how", "title":name, "claims":[["label":"Same label", "source":["ref":"\(name).go"], "explanation":name]]]
        }
        let before = try preview(["sections":[section("A"), section("B")]])
        let after = try preview(["sections":[section("X"), section("A"), section("B")]])
        XCTAssertEqual(before.previewPages[0].id, after.previewPages[1].id)
        XCTAssertEqual(before.evidenceEntries[0].id, after.evidenceEntries[1].id)
    }
    func testEvidenceIdentityIncludesItsSectionProvenance() throws {
        let claim: [String: Any] = ["label":"Same", "source":["ref":"main.go"], "explanation":"E"]
        let source: [String: Any] = ["kind":"how", "title":"Same title", "evidence_mode":"not_executed", "claims":[claim]]
        let captured: [String: Any] = ["kind":"how", "title":"Same title", "evidence_mode":"observed_running", "claims":[claim]]
        let before = try preview(["sections":[source]])
        let after = try preview(["sections":[captured, source]])
        XCTAssertEqual(before.evidenceEntries[0].id, after.evidenceEntries[1].id)
        XCTAssertNotEqual(before.evidenceEntries[0].id, after.evidenceEntries[0].id)
    }
    func testBodyOnlyActivityIsAvailableAsOrderedPreviewContent() throws {
        let repo = try preview(["sections":[["kind":"activity", "title":"Project activity", "body":"The inspected activity context."]]])
        XCTAssertEqual(repo.previewPages.count, 1)
        XCTAssertEqual(repo.previewPages.first?.body, "The inspected activity context.")
    }
    func testSameTitledSectionsAssociateTheCorrectClaimsWithEachPage() throws {
        let claim: [String: Any] = ["label":"Declared command", "source":["ref":"package.json"], "explanation":"E"]
        let repo = try preview(["sections":[["kind":"how", "title":"Shared heading", "claims":[claim]], ["kind":"setup", "title":"Shared heading", "claims":[claim]]]])
        let setup = try XCTUnwrap(repo.previewPages.first(where: { $0.kind == "setup" }))
        let setupEntry = try XCTUnwrap(repo.evidenceEntries.first(where: { $0.sectionKind == "setup" }))
        XCTAssertEqual(setup.evidenceIDs, [setupEntry.id])
        XCTAssertNotEqual(setup.evidenceIDs.first, repo.evidenceEntries.first?.id)
    }
    func testSetupSummarySkipsCaptureOnlySectionsAndRetainsLaterBodyNotes() throws {
        let capture: [String: Any] = ["kind":"setup", "title":"Capture", "media":["kind":"image", "url":"https://example.com/setup.png"]]
        let body: [String: Any] = ["kind":"setup", "title":"Setup notes", "body":"Requires the declared toolchain."]
        let command: [String: Any] = ["kind":"setup", "title":"Commands", "claims":[["label":"Declared command", "source":["ref":"package.json"], "explanation":"E"]]]
        XCTAssertEqual(try preview(["sections":[capture, body]]).setupSection?.body, "Requires the declared toolchain.")
        XCTAssertEqual(try preview(["sections":[capture, body, command]]).setupSection?.title, "Commands")
        XCTAssertNil(try preview(["sections":[capture]]).setupSection)
    }

}
