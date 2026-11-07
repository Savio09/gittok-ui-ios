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
@MainActor @Observable public final class DetailStore {
    public private(set) var preview: RepoPreview?
    public private(set) var isLoading = false
    public private(set) var error: String?
    public private(set) var walkthroughProgress: String?
    public private(set) var walkthroughMessage: String?
    private let api: any RepositoryAPI
    private let maximumPolls: Int
    private let maximumDuration: Duration
    private let wait: @Sendable (Duration) async throws -> Void
    private var generation = UUID()
    private static let unavailableMessage = "Walkthrough unavailable. You can still explore the source preview."
    public init(api: any RepositoryAPI) {
        self.api = api; maximumPolls = 120; maximumDuration = .seconds(180)
        wait = { try await Task.sleep(for: $0) }
    }
    init(api: any RepositoryAPI, maximumPolls: Int, maximumDuration: Duration = .seconds(180), wait: @escaping @Sendable (Duration) async throws -> Void) {
        self.api = api; self.maximumPolls = maximumPolls; self.maximumDuration = maximumDuration; self.wait = wait
    }
    public func cancel() {
        generation = UUID()
        isLoading = false; walkthroughProgress = nil; walkthroughMessage = nil
    }
    public func load(_ address: RepoAddress) async {
        let token = UUID(); generation = token
        preview = nil; error = nil; walkthroughProgress = nil; walkthroughMessage = nil; isLoading = true
        defer { if generation == token { isLoading = false; walkthroughProgress = nil } }
        do {
            let repo = try await api.preview(address)
            try Task.checkCancellation()
            guard generation == token else { return }
            preview = repo
            isLoading = false
        } catch {
            guard generation == token, !Task.isCancelled, !(error is CancellationError) else { return }
            self.error = error.localizedDescription
            return
        }
        // Source content remains usable during preparation. Structured children inherit
        // view-task cancellation; a separate deadline bounds even a slow poll response.
        // https://developer.apple.com/documentation/swift/taskgroup
        let deadline = maximumDuration
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.prepareWalkthrough(address, token: token) }
            group.addTask { try? await Task.sleep(for: deadline) }
            await group.next()
            group.cancelAll()
        }
        guard generation == token, !Task.isCancelled else { return }
        if walkthroughProgress != nil {
            walkthroughMessage = "The walkthrough is taking longer than expected. You can still explore the source preview."
        }
    }
    private func prepareWalkthrough(_ address: RepoAddress, token: UUID) async {
        guard generation == token, !Task.isCancelled else { return }
        guard let expectedSlug = preview?.slug else { return }
        walkthroughProgress = "Preparing the walkthrough…"
        do {
            var job = try await api.startWalkthrough(address)
            var polls = 0
            while true {
                try Task.checkCancellation()
                guard generation == token else { return }
                if job.state == "ready", let accepted = job.preview, accepted.isWalkthrough, accepted.slug.lowercased() == expectedSlug.lowercased() {
                    preview = accepted
                    walkthroughProgress = nil
                    return
                }
                guard job.isPending else {
                    walkthroughMessage = Self.unavailableMessage
                    walkthroughProgress = nil
                    return
                }
                guard polls < maximumPolls else {
                    walkthroughMessage = "The walkthrough is taking longer than expected. You can still explore the source preview."
                    walkthroughProgress = nil
                    return
                }
                walkthroughProgress = job.progressLabel
                try await wait(job.pollingDelay)
                try Task.checkCancellation()
                guard generation == token else { return }
                job = try await api.walkthrough(job.id)
                polls += 1
            }
        } catch {
            guard generation == token, !Task.isCancelled, !(error is CancellationError) else { return }
            walkthroughMessage = Self.unavailableMessage
            walkthroughProgress = nil
        }
    }
}
