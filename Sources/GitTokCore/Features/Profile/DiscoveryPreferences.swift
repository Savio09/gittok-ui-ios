import Foundation
import Observation

/// Device-local preferences; server-backed identity and sync are separate concerns.
/// https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app
@MainActor @Observable public final class DiscoveryPreferences {
    public static let defaultInterests: [String] = []
    public private(set) var saved: [RepoPreview] = []
    public var interests: [String] { profile.interests }
    public private(set) var profile = DeveloperProfile()
    public private(set) var hasCompletedOnboarding = false
    public private(set) var onboardingDisposition = OnboardingDisposition.notStarted
    public private(set) var onboardingDraft: OnboardingDraft?
    public private(set) var resetID = UUID()
    private let defaults: UserDefaults
    private let key: String
    private struct LegacySnapshot: Codable { let saved: [RepoPreview]; let interests: [String] }
    private struct Snapshot: Codable {
        let saved: [RepoPreview]
        let profile: DeveloperProfile
        let onboardingVersion: Int
        let disposition: OnboardingDisposition?
        let draft: OnboardingDraft?
    }
    public init(defaults: UserDefaults = .standard, owner: PreferenceOwner = .guest) {
        self.defaults = defaults
        key = "gittok.folio.preferences.v2." + owner.storageID
        if let data = defaults.data(forKey: key), let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) {
            saved = Self.uniqueSaved(snapshot.saved)
            profile = snapshot.profile
            hasCompletedOnboarding = snapshot.onboardingVersion >= 1
            onboardingDisposition = snapshot.disposition ?? (hasCompletedOnboarding ? .completed : .notStarted)
            onboardingDraft = snapshot.draft
        } else if owner == .guest, defaults.data(forKey: key) == nil,
                  let old = defaults.data(forKey: "gittok.folio.preferences.v1"),
                  let legacy = try? JSONDecoder().decode(LegacySnapshot.self, from: old) {
            saved = Self.uniqueSaved(legacy.saved)
            // Preserve ambiguous old defaults for review without claiming user intent.
            profile = DeveloperProfile(domains: legacy.interests)
            persist()
        }
    }
    private static func uniqueSaved(_ repos: [RepoPreview]) -> [RepoPreview] {
        var seen: Set<String> = []
        return repos.filter { seen.insert($0.slug.lowercased()).inserted }
    }
    public func saveOnboardingDraft(_ draft: OnboardingDraft) { onboardingDraft = draft; persist() }
    public func discardOnboardingDraft() { onboardingDraft = nil; persist() }
    public func completeOnboarding(_ value: DeveloperProfile, skipped: Bool = false) {
        profile = value
        onboardingDisposition = skipped ? .skipped : .completed
        hasCompletedOnboarding = true; onboardingDraft = nil; persist()
    }
    public func resetProfile() {
        profile = DeveloperProfile(); hasCompletedOnboarding = false; onboardingDisposition = .notStarted; onboardingDraft = nil
        persist()
    }
    public func isSaved(_ slug: String) -> Bool {
        saved.contains { $0.slug.caseInsensitiveCompare(slug) == .orderedSame }
    }
    public func toggleSaved(_ repo: RepoPreview) {
        if isSaved(repo.slug) { saved.removeAll { $0.slug.caseInsensitiveCompare(repo.slug) == .orderedSame } }
        else { saved.append(repo) }
        persist()
    }
    /// Cards may use a saved snapshot; a freshly fetched detail replaces that snapshot.
    public func updateSaved(_ repo: RepoPreview) {
        guard let index = saved.firstIndex(where: { $0.slug.caseInsensitiveCompare(repo.slug) == .orderedSame }) else { return }
        saved[index] = repo
        persist()
    }
    public func toggleInterest(_ raw: String) {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        let matches: (String) -> Bool = { $0.caseInsensitiveCompare(value) == .orderedSame }
        if interests.contains(where: matches) {
            profile.knownTechnologies.removeAll(where: matches)
            profile.learningTechnologies.removeAll(where: matches)
            profile.domains.removeAll(where: matches)
        } else { profile.domains.append(value) }
        onboardingDraft = nil
        persist()
    }
    public func reset() {
        saved = []; profile = DeveloperProfile(); onboardingDraft = nil; hasCompletedOnboarding = false; onboardingDisposition = .notStarted; resetID = UUID()
        persist()
    }
    private func persist() {
        if let data = try? JSONEncoder().encode(Snapshot(saved: saved, profile: profile, onboardingVersion: hasCompletedOnboarding ? 1 : 0, disposition: onboardingDisposition, draft: onboardingDraft)) { defaults.set(data, forKey: key) }
    }
}

public enum DiscoveryQuery {
    public static func results(_ repos: [RepoPreview], query: String, filter: String, interests: [String], personalized: Bool) -> [RepoPreview] {
        let search = normalized(query.trimmingCharacters(in: .whitespacesAndNewlines))
        let filtered = repos.filter { repo in
            let matchesFilter = filter == "All" || normalized(repo.kindTitle) == normalized(filter) || normalized(repo.language ?? "") == normalized(filter)
            let text = normalized([repo.slug, repo.description, repo.headline ?? "", repo.kindTitle, repo.language ?? ""].joined(separator: " "))
            return matchesFilter && (search.isEmpty || text.contains(search))
        }
        guard personalized else { return filtered }
        return filtered.enumerated().sorted { a, b in
            let first = matchingInterests(a.element, interests: interests).count
            let second = matchingInterests(b.element, interests: interests).count
            return first == second ? a.offset < b.offset : first > second
        }.map(\.element)
    }
    /// Local lexical matching uses provider metadata, never excerpts, limits, or inferred runtime facts.
    public static func matchingInterests(_ repo: RepoPreview, interests: [String]) -> [String] {
        let metadata = words([repo.description, repo.headline ?? ""].joined(separator: " "))
        return interests.filter {
            let value = normalized($0)
            if value == normalized(repo.kindTitle) || value == normalized(repo.language ?? "") { return true }
            // Language/type choices require the corresponding metadata field. In
            // particular, Go must not match Django, MongoDB, or a migration note.
            guard ["developer tools", "local first", "open source"].contains(value) else { return false }
            return (" " + metadata + " ").contains(" " + words(value) + " ")
        }
    }
    private static func words(_ value: String) -> String {
        value.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: " ")
    }
    private static func normalized(_ value: String) -> String {
        value.lowercased().replacingOccurrences(of: "-", with: " ")
    }
}
