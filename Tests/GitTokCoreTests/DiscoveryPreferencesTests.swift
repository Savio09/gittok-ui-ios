import XCTest
@testable import GitTokCore

@MainActor final class DiscoveryPreferencesTests: XCTestCase {
    private func repository(_ slug: String, kind: String = "other", language: String = "Go") throws -> RepoPreview {
        let parts = slug.split(separator: "/")
        let object: [String: Any] = ["id": slug, "owner": String(parts[0]), "name": String(parts[1]), "slug": slug, "kind": kind, "language": language, "description": "A repository", "github_url": "https://github.com/\(slug)"]
        return try Wire.decoder().decode(RepoPreview.self, from: JSONSerialization.data(withJSONObject: object))
    }
    private func isolatedDefaults() -> UserDefaults {
        UserDefaults(suiteName: "dev.gittok.tests.\(UUID().uuidString)")!
    }
    func testBookmarksPersistAndUseCaseInsensitiveRepositoryIdentity() throws {
        let defaults = isolatedDefaults()
        let first = DiscoveryPreferences(defaults: defaults)
        let repo = try repository("Owner/Project")
        first.toggleSaved(repo)
        XCTAssertTrue(first.isSaved("owner/project"))
        let reloaded = DiscoveryPreferences(defaults: defaults)
        XCTAssertEqual(reloaded.saved.map(\.slug), ["Owner/Project"])
        reloaded.toggleSaved(try repository("owner/project"))
        XCTAssertTrue(reloaded.saved.isEmpty)
        XCTAssertTrue(DiscoveryPreferences(defaults: defaults).saved.isEmpty)
    }
    func testResetClearsBookmarksAndRestoresDefaultInterests() throws {
        let defaults = isolatedDefaults()
        let subject = DiscoveryPreferences(defaults: defaults)
        subject.toggleSaved(try repository("o/r"))
        subject.toggleInterest("TypeScript")
        subject.reset()
        let restored = DiscoveryPreferences(defaults: defaults)
        XCTAssertTrue(restored.saved.isEmpty)
        XCTAssertEqual(restored.interests, DiscoveryPreferences.defaultInterests)
    }
    func testInterestsPersistAndDoNotDuplicateCaseVariants() {
        let defaults = isolatedDefaults()
        let subject = DiscoveryPreferences(defaults: defaults)
        subject.toggleInterest("TypeScript")
        XCTAssertTrue(DiscoveryPreferences(defaults: defaults).interests.contains("TypeScript"))
        subject.toggleInterest("typescript")
        XCTAssertFalse(subject.interests.contains { $0.lowercased() == "typescript" })
    }
    func testForYouUsesMetadataAndRetainsProviderOrderForTies() throws {
        let repos = try [repository("o/first", language: "Rust"), repository("o/second", kind: "backend"), repository("o/third", kind: "backend")]
        let ranked = DiscoveryQuery.results(repos, query: "", filter: "All", interests: ["Backend", "Go"], personalized: true)
        XCTAssertEqual(ranked.map(\.slug), ["o/second", "o/third", "o/first"])
        XCTAssertEqual(DiscoveryQuery.results(repos, query: "", filter: "All", interests: [], personalized: true).map(\.slug), repos.map(\.slug))
    }
    func testSearchAndFilterApplyTogetherForArbitraryKindsAndLanguages() throws {
        let repos = try [repository("o/runner", kind: "cli", language: "Zig"), repository("o/other", kind: "library", language: "Zig")]
        XCTAssertEqual(DiscoveryQuery.results(repos, query: "runner", filter: "Zig", interests: [], personalized: false).map(\.slug), ["o/runner"])
        XCTAssertEqual(DiscoveryQuery.results(repos, query: "", filter: "Command line", interests: [], personalized: false).map(\.slug), ["o/runner"])
        XCTAssertTrue(DiscoveryQuery.results(repos, query: "missing", filter: "All", interests: [], personalized: false).isEmpty)
    }
    func testSavedSnapshotsPreserveAllEvidenceButCanBeUpdatedAfterLiveFetch() throws {
        let json = #"{"id":"o/r","owner":"o","name":"r","slug":"o/r","kind":"cli","description":"D","github_url":"https://github.com/o/r","sections":[{"kind":"how","title":"How","evidence_mode":"not_executed","claims":[{"label":"Entry","source":{"ref":"main.go","lines":"1-2"},"additional_sources":[{"ref":"go.mod"}],"evidence_status":"inferred","explanation":"E","excerpt":"func main(){}","supports":"S","limit":"L"}]}]}"#
        let repo = try Wire.decoder().decode(RepoPreview.self, from: Data(json.utf8))
        let defaults = isolatedDefaults()
        let subject = DiscoveryPreferences(defaults: defaults)
        subject.toggleSaved(repo)
        let restored = DiscoveryPreferences(defaults: defaults).saved[0]
        let claim = try XCTUnwrap(restored.sections?.first?.claims?.first)
        XCTAssertEqual(claim.allSources.count, 2)
        XCTAssertEqual(claim.status, .inferred)
        XCTAssertEqual(claim.excerpt, "func main(){}")
        XCTAssertEqual(claim.limit, "L")
        subject.updateSaved(try repository("o/r", kind: "library", language: "Rust"))
        XCTAssertEqual(DiscoveryPreferences(defaults: defaults).saved.first?.language, "Rust")
    }
    func testLanguageInterestsRequireLanguageMetadata() throws {
        for description in ["Django and MongoDB", "An algorithm library", "Explains migration from Go to Python"] {
            let object: [String: Any] = ["id":"o/r", "owner":"o", "name":"r", "slug":"o/r", "kind":"backend", "language":"Python", "description":description, "github_url":"https://github.com/o/r"]
            let repo = try Wire.decoder().decode(RepoPreview.self, from: JSONSerialization.data(withJSONObject: object))
            XCTAssertTrue(DiscoveryQuery.matchingInterests(repo, interests: ["Go"]).isEmpty)
        }
    }
}
