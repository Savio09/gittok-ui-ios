import XCTest
@testable import GitTokCore

@MainActor final class OnboardingTests: XCTestCase {
    private func defaults() -> UserDefaults { UserDefaults(suiteName: "dev.gittok.profile-tests.\(UUID().uuidString)")! }
    func testFreshUserHasNoInventedInterestsOrCompletedOnboarding() {
        let p = DiscoveryPreferences(defaults: defaults())
        XCTAssertTrue(p.interests.isEmpty)
        XCTAssertFalse(p.hasCompletedOnboarding)
    }
    func testDraftResumesButDoesNotCommitUntilCompletion() {
        let d = defaults(); let p = DiscoveryPreferences(defaults: d)
        let profile = DeveloperProfile(knownTechnologies: ["Swift"], learningTechnologies: ["Go"], domains: ["Mobile"], goal: .firstContribution)
        p.saveOnboardingDraft(OnboardingDraft(step: .goals, profile: profile))
        let resumed = DiscoveryPreferences(defaults: d)
        XCTAssertEqual(resumed.onboardingDraft?.step, .goals)
        XCTAssertTrue(resumed.interests.isEmpty)
        resumed.completeOnboarding(profile)
        let saved = DiscoveryPreferences(defaults: d)
        XCTAssertTrue(saved.hasCompletedOnboarding)
        XCTAssertEqual(saved.profile, profile)
        XCTAssertEqual(Set(saved.interests), ["Swift", "Go", "Mobile"])
        XCTAssertNil(saved.onboardingDraft)
    }
    func testCancellingProfileEditKeepsCompletedProfile() {
        let p = DiscoveryPreferences(defaults: defaults())
        let original = DeveloperProfile(knownTechnologies: ["Go"], goal: .learnCodebase)
        p.completeOnboarding(original)
        p.saveOnboardingDraft(OnboardingDraft(step: .skills, profile: DeveloperProfile()))
        p.discardOnboardingDraft()
        XCTAssertEqual(p.profile, original)
        XCTAssertTrue(p.hasCompletedOnboarding)
    }
    func testOwnersNeverImplicitlyImportEachOthersData() {
        let d = defaults(); let guest = DiscoveryPreferences(defaults: d)
        guest.completeOnboarding(DeveloperProfile(knownTechnologies: ["Swift"]))
        let a = DiscoveryPreferences(defaults: d, owner: .account(instance: "one", userID: "A"))
        XCTAssertTrue(a.interests.isEmpty)
        a.completeOnboarding(DeveloperProfile(knownTechnologies: ["Go"]))
        XCTAssertTrue(DiscoveryPreferences(defaults: d, owner: .account(instance: "one", userID: "B")).interests.isEmpty)
        XCTAssertTrue(DiscoveryPreferences(defaults: d, owner: .account(instance: "two", userID: "A")).interests.isEmpty)
        XCTAssertEqual(DiscoveryPreferences(defaults: d).interests, ["Swift"])
        XCTAssertEqual(DiscoveryPreferences(defaults: d, owner: .account(instance: "one", userID: "A")).interests, ["Go"])
    }
    func testLegacySnapshotMigratesOnceOnlyToGuestAndKeepsOriginal() throws {
        let d = defaults()
        let repo = try Wire.decoder().decode(RepoPreview.self, from: Data(#"{"id":"o/r","owner":"o","name":"r","slug":"o/r","kind":"library","description":"Saved","github_url":"https://github.com/o/r","sections":[{"kind":"source","title":"How it works","claims":[{"id":"claim-1","label":"Handler","source":{"kind":"file","ref":"src/main.go","lines":"12-18","url":"https://github.com/o/r/blob/abc/src/main.go#L12-L18"},"additional_sources":[{"kind":"file","ref":"src/handler.go","lines":"5-9"}],"excerpt":"func main()","explanation":"Calls the request handler.","evidence_status":"supported"}]}]}"#.utf8))
        struct Legacy: Encodable { let saved: [RepoPreview]; let interests: [String] }
        // Real v1 used JSONEncoder's camel-case persisted representation, not the wire decoder.
        let bytes = try JSONEncoder().encode(Legacy(saved: [repo], interests: ["Rust", "Backend"]))
        d.set(bytes, forKey: "gittok.folio.preferences.v1")
        let guest = DiscoveryPreferences(defaults: d)
        XCTAssertEqual(guest.saved.map(\.slug), ["o/r"])
        XCTAssertEqual(try JSONSerialization.jsonObject(with: JSONEncoder().encode(guest.saved[0])) as? NSDictionary,
                       try JSONSerialization.jsonObject(with: JSONEncoder().encode(repo)) as? NSDictionary)
        XCTAssertEqual(guest.saved[0].sections?.first?.claims?.first?.allSources.count, 2)
        XCTAssertEqual(guest.saved[0].sections?.first?.claims?.first?.source.lines, "12-18")
        XCTAssertEqual(guest.interests, ["Rust", "Backend"])
        XCTAssertFalse(guest.hasCompletedOnboarding)
        XCTAssertEqual(d.data(forKey: "gittok.folio.preferences.v1"), bytes)
        guest.toggleInterest("Python")
        XCTAssertTrue(DiscoveryPreferences(defaults: d).interests.contains("Python"))
        XCTAssertTrue(DiscoveryPreferences(defaults: d, owner: .account(instance: "one", userID: "A")).saved.isEmpty)
    }
    func testProfileResetDoesNotDeleteBookmarks() throws {
        let p = DiscoveryPreferences(defaults: defaults())
        let bytes = Data(#"{"id":"o/r","owner":"o","name":"r","slug":"o/r","kind":"other","description":"D","github_url":"https://github.com/o/r"}"#.utf8)
        p.toggleSaved(try Wire.decoder().decode(RepoPreview.self, from: bytes))
        p.completeOnboarding(DeveloperProfile(knownTechnologies: ["Go"]))
        p.resetProfile()
        XCTAssertEqual(p.saved.count, 1)
        XCTAssertTrue(p.interests.isEmpty)
    }
    func testRemovingInterestUpdatesEveryProfileBucketAndSurvivesReplay() {
        let d = defaults(); let p = DiscoveryPreferences(defaults: d)
        p.completeOnboarding(DeveloperProfile(knownTechnologies: ["Go"], learningTechnologies: ["Rust"]))
        p.toggleInterest("go"); p.toggleInterest("RUST")
        XCTAssertTrue(p.profile.knownTechnologies.isEmpty)
        XCTAssertTrue(p.profile.learningTechnologies.isEmpty)
        XCTAssertTrue(p.profile.interests.isEmpty)
        p.completeOnboarding(p.profile)
        XCTAssertTrue(DiscoveryPreferences(defaults: d).interests.isEmpty)
    }

    func testSkipRecordsAnExplicitDisposition() {
        let d = defaults(); let p = DiscoveryPreferences(defaults: d)
        p.completeOnboarding(DeveloperProfile(), skipped: true)
        let restored = DiscoveryPreferences(defaults: d)
        XCTAssertTrue(restored.hasCompletedOnboarding)
        XCTAssertEqual(restored.onboardingDisposition, .skipped)
    }

    func testCommittedInterestChangeRetiresStaleEditDraft() {
        let d = defaults(); let p = DiscoveryPreferences(defaults: d)
        p.completeOnboarding(DeveloperProfile(knownTechnologies: ["Go"]))
        p.saveOnboardingDraft(OnboardingDraft(step: .skills, profile: p.profile))
        p.toggleInterest("go")
        let restored = DiscoveryPreferences(defaults: d)
        XCTAssertNil(restored.onboardingDraft)
        XCTAssertTrue(restored.interests.isEmpty)
    }
    func testEditChoicesIncludeLegacyValuesAndUseCaseInsensitiveIdentity() {
        let values = ProfileSelection.options(available: ["Frontend", "Backend"], selected: ["backend", "Zig"])
        XCTAssertEqual(values, ["Frontend", "Backend", "Zig"])
        XCTAssertTrue(ProfileSelection.contains("Backend", in: ["backend"]))
        XCTAssertEqual(ProfileSelection.toggling("Backend", in: ["backend", "Zig"]), ["Zig"])
    }
}
