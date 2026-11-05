import XCTest
@testable import GitTokCore

final class ContractTests: XCTestCase {
    func testLegacyConfidenceNeverBecomesSupported() throws {
        let data = Data(#"{"id":"1","owner":"o","name":"r","slug":"o/r","kind":"future_kind","description":"D","github_url":"https://github.com/o/r","sections":[{"kind":"future_section","title":"Source","claims":[{"label":"Claim","source":{"ref":"README.md"},"confidence":"confident","explanation":"E","additional_sources":[{"ref":"package.json"}]}]}]}"#.utf8)
        let repo = try Wire.decoder().decode(RepoPreview.self, from: data)
        XCTAssertEqual(repo.kindStatus, .unknown)
        XCTAssertEqual(repo.sections?.first?.claims?.first?.status, .unknown)
        XCTAssertEqual(repo.sections?.first?.claims?.first?.allSources.count, 2)
    }
    func testFutureEvidenceStatusIsUnknown() throws {
        XCTAssertEqual(try JSONDecoder().decode(EvidenceStatus.self, from: Data(#""future""#.utf8)), .unknown)
    }
    func testExecutionLabelsNeverInventExecutionKnowledge() {
        XCTAssertEqual(ExecutionEvidence.label(for: nil), "Execution unknown")
        XCTAssertEqual(ExecutionEvidence.label(for: "future_mode"), "Execution unknown")
        XCTAssertEqual(ExecutionEvidence.label(for: "not_executed"), "Not executed")
        XCTAssertEqual(ExecutionEvidence.label(for: "observed_running"), "Observed running")
    }
    func testURLBoundaryRejectsExecutableSchemesAndCredentials() throws {
        XCTAssertNil(SafeURL.link("javascript:alert(1)"))
        XCTAssertNil(SafeURL.link("https://user:pass@github.com/o/r"))
        XCTAssertNotNil(SafeURL.link("https://github.com/o/r"))
        XCTAssertThrowsError(try APIClient.validatedBaseURL("file:///etc/passwd"))
        XCTAssertThrowsError(try RepoAddress("../escape"))
        XCTAssertEqual(try RepoAddress("apple/swift").slug, "apple/swift")
    }
}
