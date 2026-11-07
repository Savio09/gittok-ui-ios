import Foundation
import Observation

// Observation keeps request state separate from presentation.
// https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app
@MainActor @Observable public final class FeedStore {
    public private(set) var items: [RepoPreview] = []
    public private(set) var nextCursor: String?
    public private(set) var isLoading = false
    public private(set) var isLoadingMore = false
    public private(set) var error: String?
    public private(set) var paginationFailed = false
    private let api: any RepositoryAPI
    private var generation = UUID()
    public init(api: any RepositoryAPI) { self.api = api }
    public func refresh() async {
        let token = UUID(); generation = token
        isLoading = true; isLoadingMore = false; error = nil; paginationFailed = false
        defer { if generation == token { isLoading = false } }
        do {
            let page = try await api.feed(cursor: nil)
            try Task.checkCancellation()
            guard generation == token else { return }
            items = unique(page.items)
            nextCursor = page.nextCursor.flatMap { $0.isEmpty ? nil : $0 }
        } catch {
            guard generation == token, !Task.isCancelled, !(error is CancellationError) else { return }
            self.error = error.localizedDescription
        }
    }
    public func loadMore() async {
        guard !isLoading, !isLoadingMore, let cursor = nextCursor else { return }
        let token = generation
        isLoadingMore = true; error = nil; paginationFailed = false
        defer { if generation == token { isLoadingMore = false } }
        do {
            let page = try await api.feed(cursor: cursor)
            try Task.checkCancellation()
            guard generation == token else { return }
            items = unique(items + page.items)
            nextCursor = page.nextCursor.flatMap { $0.isEmpty || $0 == cursor ? nil : $0 }
        } catch {
            guard generation == token, !Task.isCancelled, !(error is CancellationError) else { return }
            self.error = error.localizedDescription
            paginationFailed = true
            if case APIError.http(400, _) = error { nextCursor = nil }
        }
    }
    public func retry() async {
        if paginationFailed, nextCursor != nil { await loadMore() }
        else { await refresh() }
    }
    private func unique(_ repos: [RepoPreview]) -> [RepoPreview] {
        var slugs: Set<String> = []
        var identities: Set<Int64> = []
        return repos.filter { repo in
            let slug = repo.slug.lowercased()
            let identity = repo.githubId.flatMap { $0 > 0 ? $0 : nil }
            guard !slugs.contains(slug), identity.map({ !identities.contains($0) }) ?? true else { return false }
            slugs.insert(slug)
            if let identity { identities.insert(identity) }
            return true
        }
    }
}
