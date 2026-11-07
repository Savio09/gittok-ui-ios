import Foundation
import Observation

/// Device-local preferences; server-backed identity and sync are separate concerns.
/// https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app
@MainActor @Observable public final class DiscoveryPreferences {
    public static let defaultInterests = ["Backend", "Go"]
    public private(set) var saved: [RepoPreview] = []
    public private(set) var interests = defaultInterests
    public private(set) var resetID = UUID()
    private let defaults: UserDefaults
    private let key = "gittok.folio.preferences.v1"

    private struct Snapshot: Codable {
        let saved: [RepoPreview]
        let interests: [String]
    }
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key), let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) {
            var seen: Set<String> = []
            saved = snapshot.saved.filter { seen.insert($0.slug.lowercased()).inserted }
            interests = snapshot.interests
        }
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
    public func toggleInterest(_ value: String) {
        if let index = interests.firstIndex(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) { interests.remove(at: index) }
        else { interests.append(value) }
        persist()
    }
    public func reset() {
        saved = []; interests = Self.defaultInterests; resetID = UUID()
        persist()
    }
    private func persist() {
        if let data = try? JSONEncoder().encode(Snapshot(saved: saved, interests: interests)) { defaults.set(data, forKey: key) }
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
