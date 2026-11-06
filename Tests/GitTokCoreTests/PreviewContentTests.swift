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
        XCTAssertEqual(repo.previewPages.first?.evidenceMode, "observed_running")
        XCTAssertNil(repo.previewPages.last?.evidenceMode)
        XCTAssertNil(repo.evidenceEntries.first?.evidenceMode)
    }
    func testMissingMediaModeRemainsUnknownEvenWhenSectionIsObserved() throws {
        let repo = try preview(["sections":[["kind":"how", "title":"Capture", "evidence_mode":"observed_running", "media":["kind":"image", "url":"https://example.com/shot.png"]]]])
        XCTAssertNil(repo.previewPages.first?.evidenceMode)
        XCTAssertEqual(ExecutionEvidence.label(for: repo.previewPages.first?.evidenceMode), "Execution unknown")
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
}
