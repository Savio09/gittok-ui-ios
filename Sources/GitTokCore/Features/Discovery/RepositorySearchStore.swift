import Foundation
import Observation

@MainActor @Observable public final class RepositorySearchStore {
    public var query = "" {
        didSet {
            guard query != oldValue else { return }
            requestID = UUID()
            items = []; nextCursor = nil; requestedCursor = nil; error = nil
            hasSearched = false; isLoadingMore = false
            isLoading = !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    public private(set) var requestID = UUID()
    public private(set) var items: [RepoPreview] = []
    public private(set) var nextCursor: String?
    public private(set) var isLoading = false
    public private(set) var isLoadingMore = false
    public private(set) var hasSearched = false
    public private(set) var error: String?
    private var requestedCursor: String?
    private let api: any RepositoryAPI
    private let debounce: Duration

    public init(api: any RepositoryAPI, debounce: Duration = .milliseconds(350)) {
        self.api = api; self.debounce = debounce
    }
    public func requestMore() {
        guard !isLoading, !isLoadingMore, let nextCursor else { return }
        requestedCursor = nextCursor; isLoadingMore = true; error = nil; requestID = UUID()
    }
    public func retry() {
        guard !isLoading, !isLoadingMore else { return }
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        error = nil
        isLoadingMore = requestedCursor != nil
        isLoading = requestedCursor == nil
        requestID = UUID()
    }
    public func cancel() {
        requestID = UUID(); isLoading = false; isLoadingMore = false
    }
    // SwiftUI .task(id:) cancels the transport on edits/dismissal; requestID also rejects non-cooperative late responses.
    // https://developer.apple.com/documentation/swiftui/view/task(id:priority:_:)
    public func performRequest() async {
        let token = requestID, cursor = requestedCursor
        guard !Task.isCancelled, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        defer { if requestID == token { isLoading = false; isLoadingMore = false } }
        do {
            let value = try APIClient.validatedSearchQuery(query)
            isLoading = cursor == nil; isLoadingMore = cursor != nil
            if cursor == nil { isLoading = true; try await Task.sleep(for: debounce) }
            try Task.checkCancellation()
            guard requestID == token else { return }
            let page = try await api.search(query: value, cursor: cursor)
            try Task.checkCancellation()
            guard requestID == token else { return }
            var slugs = Set<String>(), identities = Set<Int64>()
            items = ((cursor == nil ? [] : items) + page.items).filter { repo in
                let slug = repo.slug.lowercased()
                let identity = repo.githubId.flatMap { $0 > 0 ? $0 : nil }
                guard !slugs.contains(slug), identity.map({ !identities.contains($0) }) ?? true else { return false }
                slugs.insert(slug); if let identity { identities.insert(identity) }; return true
            }
            nextCursor = page.nextCursor.flatMap { $0.isEmpty || $0 == cursor ? nil : $0 }
            requestedCursor = nil; hasSearched = true; error = nil
        } catch {
            guard requestID == token, !Task.isCancelled, !(error is CancellationError) else { return }
            if case APIError.http(_, let message) = error { self.error = message }
            else { self.error = error.localizedDescription }
            if case APIError.http(400, _) = error { nextCursor = nil; requestedCursor = nil }
        }
    }
}
