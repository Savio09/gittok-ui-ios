import XCTest
@testable import GitTokCore

private actor ControlledAPI: RepositoryAPI {
    var requests: [String?] = []
    var waiters: [Int: CheckedContinuation<Feed, any Error>] = [:]
    var detailWaiters: [Int: CheckedContinuation<RepoPreview, any Error>] = [:]
    var detailCount = 0
    func feed(cursor: String?) async throws -> Feed {
        let index = requests.count; requests.append(cursor)
        return try await withCheckedThrowingContinuation { waiters[index] = $0 }
    }
    func preview(_ address: RepoAddress) async throws -> RepoPreview {
        let index = detailCount; detailCount += 1
        return try await withCheckedThrowingContinuation { detailWaiters[index] = $0 }
    }
    func waitForFeed(_ count: Int) async {
        while requests.count < count { await Task.yield() }
    }
    func waitForDetail(_ count: Int) async {
        while detailCount < count { await Task.yield() }
    }
    func resolve(_ index: Int, _ result: Result<Feed, any Error>) { waiters.removeValue(forKey: index)!.resume(with: result) }
    func resolveDetail(_ index: Int, _ result: Result<RepoPreview, any Error>) { detailWaiters.removeValue(forKey: index)!.resume(with: result) }
}
@MainActor final class StoreTests: XCTestCase {
    func testLivePagesDeduplicateRepositoryRenamesByGitHubIdentity() async throws {
        let api = ControlledAPI(); let store = FeedStore(api: api)
        let old = try Wire.decoder().decode(RepoPreview.self, from: Data(#"{"id":"o/old","github_id":42,"owner":"o","name":"old","slug":"o/old","kind":"other","description":"D","github_url":"https://github.com/o/old"}"#.utf8))
        let renamed = try Wire.decoder().decode(RepoPreview.self, from: Data(#"{"id":"o/new","github_id":42,"owner":"o","name":"new","slug":"o/new","kind":"other","description":"D","github_url":"https://github.com/o/new"}"#.utf8))
        let first = Task { await store.refresh() }; await api.waitForFeed(1)
        await api.resolve(0, .success(Feed(items: [old], nextCursor: "next"))); await first.value
        let more = Task { await store.loadMore() }; await api.waitForFeed(2)
        await api.resolve(1, .success(Feed(items: [renamed], nextCursor: nil))); await more.value
        XCTAssertEqual(store.items.count, 1)
    }
    func testExpiredCursorRetryRefreshesInsteadOfRepeatingInvalidPage() async throws {
        let api = ControlledAPI(); let store = FeedStore(api: api)
        let first = Task { await store.refresh() }; await api.waitForFeed(1)
        await api.resolve(0, .success(try page(["one"], cursor: "expired"))); await first.value
        let more = Task { await store.loadMore() }; await api.waitForFeed(2)
        await api.resolve(1, .failure(APIError.http(400, "Refresh the collection"))); await more.value
        XCTAssertEqual(store.items.count, 1)
        let retry = Task { await store.retry() }; await api.waitForFeed(3)
        let requested = await api.requests; XCTAssertNil(requested[2])
        await api.resolve(2, .success(try page(["two"]))); await retry.value
        XCTAssertEqual(store.items.map(\.name), ["two"])
    }
    private func repo(_ name: String) throws -> RepoPreview {
        try Wire.decoder().decode(RepoPreview.self, from: Data("{\"id\":\"\(name)\",\"owner\":\"o\",\"name\":\"\(name)\",\"slug\":\"o/\(name)\",\"kind\":\"other\",\"description\":\"D\",\"github_url\":\"https://github.com/o/\(name)\"}".utf8))
    }
    private func page(_ names: [String], cursor: String? = nil) throws -> Feed {
        // The feed constructor is intentionally internal to the module; use wire data like a real response.
        let repos = try names.map { try repo($0) }
        return Feed(items: repos, nextCursor: cursor)
    }
    func testPaginationFailurePreservesItemsAndCursorThenRetryDeduplicates() async throws {
        let api = ControlledAPI()
        let subject = FeedStore(api: api)
        let refresh = Task { await subject.refresh() }; await api.waitForFeed(1)
        await api.resolve(0, .success(try page(["one"], cursor: "opaque"))); await refresh.value
        let earlier = Task { await subject.loadMore() }; await api.waitForFeed(2)
        await api.resolve(1, .success(try page(["two"], cursor: "third"))); await earlier.value
        let more = Task { await subject.loadMore() }; await api.waitForFeed(3)
        await api.resolve(2, .failure(APIError.http(503, "Try later"))); await more.value
        XCTAssertEqual(subject.items.map(\.name), ["one", "two"]); XCTAssertEqual(subject.nextCursor, "third")
        XCTAssertNotNil(subject.error); XCTAssertFalse(subject.isLoadingMore)
        let retry = Task { await subject.retry() }; await api.waitForFeed(4)
        let requested = await api.requests
        XCTAssertEqual(requested[3], "third")
        await api.resolve(3, .success(try page(["two", "three"]))); await retry.value
        XCTAssertEqual(subject.items.map(\.name), ["one", "two", "three"])
        XCTAssertNil(subject.nextCursor); XCTAssertNil(subject.error)
    }
    func testRefreshWinsRaceAgainstEarlierPagination() async throws {
        let api = ControlledAPI()
        let store = FeedStore(api: api)
        let initial = Task { await store.refresh() }; await api.waitForFeed(1)
        await api.resolve(0, .success(try page(["one"], cursor: "next"))); await initial.value
        let more = Task { await store.loadMore() }; await api.waitForFeed(2)
        let refresh = Task { await store.refresh() }; await api.waitForFeed(3)
        await api.resolve(2, .success(try page(["new"]))); await refresh.value
        await api.resolve(1, .success(try page(["stale"], cursor: "bad"))); await more.value
        XCTAssertEqual(store.items.map(\.name), ["new"]); XCTAssertNil(store.nextCursor)
        XCTAssertFalse(store.isLoadingMore); XCTAssertFalse(store.isLoading)
    }
    func testCancelledRefreshClearsLoadingWithoutShowingError() async throws {
        let api = ControlledAPI()
        let store = FeedStore(api: api)
        let task = Task { await store.refresh() }; await api.waitForFeed(1); task.cancel()
        await api.resolve(0, .success(try page(["cancelled"]))); await task.value
        XCTAssertTrue(store.items.isEmpty); XCTAssertNil(store.error); XCTAssertFalse(store.isLoading)
    }
    func testDetailClearsPreviousRepoAndRejectsStaleResponse() async throws {
        let api = ControlledAPI()
        let subject = DetailStore(api: api)
        let first = Task { await subject.load(try! RepoAddress("o/one")) }; await api.waitForDetail(1)
        await api.resolveDetail(0, .success(try repo("one"))); await first.value
        let second = Task { await subject.load(try! RepoAddress("o/two")) }; await api.waitForDetail(2)
        XCTAssertNil(subject.preview); XCTAssertTrue(subject.isLoading)
        let third = Task { await subject.load(try! RepoAddress("o/three")) }; await api.waitForDetail(3)
        await api.resolveDetail(2, .failure(APIError.http(404, "Missing"))); await third.value
        await api.resolveDetail(1, .success(try repo("two"))); await second.value
        XCTAssertNil(subject.preview); XCTAssertNotNil(subject.error); XCTAssertFalse(subject.isLoading)
    }
}


private actor WalkthroughAPI: RepositoryAPI {
    let source: RepoPreview
    private var waiters: [Int: CheckedContinuation<WalkthroughJob, any Error>] = [:]
    private(set) var jobRequests = 0
    private(set) var pollIDs: [String] = []
    init(source: RepoPreview) { self.source = source }
    func feed(cursor: String?) async throws -> Feed { Feed(items: [], nextCursor: nil) }
    func preview(_ address: RepoAddress) async throws -> RepoPreview { source }
    func startWalkthrough(_ address: RepoAddress) async throws -> WalkthroughJob { try await response() }
    func walkthrough(_ id: String) async throws -> WalkthroughJob { pollIDs.append(id); return try await response() }
    private func response() async throws -> WalkthroughJob {
        let index = jobRequests; jobRequests += 1
        return try await withCheckedThrowingContinuation { waiters[index] = $0 }
    }
    func waitForJob(_ count: Int) async { while jobRequests < count { await Task.yield() } }
    func resolve(_ index: Int, _ value: Result<WalkthroughJob, any Error>) { waiters.removeValue(forKey: index)!.resume(with: value) }
}
private actor PollDelays {
    private(set) var values: [Duration] = []
    func record(_ delay: Duration) { values.append(delay) }
}
@MainActor final class WalkthroughStoreTests: XCTestCase {
    private func repo(presentation: String? = nil, slug: String = "o/r") throws -> RepoPreview {
        var fields: [String: Any] = ["id":slug, "owner":"o", "name":"r", "slug":slug, "kind":"other", "description":"Source notes remain available.", "github_url":"https://github.com/\(slug)"]
        if let presentation { fields["presentation"] = presentation }
        return try Wire.decoder().decode(RepoPreview.self, from: JSONSerialization.data(withJSONObject: fields))
    }
    private func job(_ state: String, delay: Int = 250, preview: RepoPreview? = nil) throws -> WalkthroughJob {
        var fields: [String: Any] = ["id":"job-1", "state":state, "poll_after_ms":delay, "message":"Do not expose provider configuration details"]
        if let preview { fields["preview"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(preview)) }
        return try Wire.decoder().decode(WalkthroughJob.self, from: JSONSerialization.data(withJSONObject: fields))
    }
    func testRedirectedRepositoryUsesResolvedSourceIdentity() async throws {
        let canonical = "new-owner/new-name"
        let api = WalkthroughAPI(source: try repo(slug: canonical))
        let subject = DetailStore(api: api)
        let loading = Task { await subject.load(try! RepoAddress("old-owner/old-name")) }
        await api.waitForJob(1)
        await api.resolve(0, .success(try job("ready", preview: repo(presentation: "walkthrough", slug: canonical))))
        await loading.value
        XCTAssertTrue(subject.preview?.isWalkthrough == true)
        XCTAssertNil(subject.walkthroughMessage)
    }
    func testSourceAppearsBeforePreparationAndAcceptedStoryReplacesIt() async throws {
        let api = WalkthroughAPI(source: try repo())
        let subject = DetailStore(api: api, maximumPolls: 8, wait: { _ in await Task.yield() })
        let loading = Task { await subject.load(try! RepoAddress("o/r")) }
        await api.waitForJob(1)
        XCTAssertEqual(subject.preview?.description, "Source notes remain available.")
        XCTAssertFalse(subject.isLoading)
        await api.resolve(0, .success(try job("queued")))
        await api.waitForJob(2)
        XCTAssertNotNil(subject.walkthroughProgress)
        await api.resolve(1, .success(try job("reading")))
        await api.waitForJob(3)
        XCTAssertEqual(subject.walkthroughProgress, "Reading the project’s sources…")
        await api.resolve(2, .success(try job("writing")))
        await api.waitForJob(4)
        XCTAssertEqual(subject.walkthroughProgress, "Preparing the walkthrough…")
        await api.resolve(3, .success(try job("reviewing")))
        await api.waitForJob(5)
        XCTAssertEqual(subject.walkthroughProgress, "Checking the walkthrough’s sources…")
        await api.resolve(4, .success(try job("ready", preview: repo(presentation: "walkthrough"))))
        await loading.value
        XCTAssertTrue(subject.preview?.isWalkthrough == true)
        XCTAssertNil(subject.walkthroughProgress)
        XCTAssertNil(subject.walkthroughMessage)
        XCTAssertNil(subject.error)
    }
    func testTerminalAndUnknownStatesKeepSourcePreviewWithHonestMessage() async throws {
        for state in ["failed", "interrupted", "cancelled", "unavailable", "future_state", "ready"] {
            let api = WalkthroughAPI(source: try repo())
            let subject = DetailStore(api: api)
            let loading = Task { await subject.load(try! RepoAddress("o/r")) }
            await api.waitForJob(1)
            await api.resolve(0, .success(try job(state)))
            await loading.value
            XCTAssertFalse(subject.preview?.isWalkthrough ?? true, state)
            XCTAssertNotNil(subject.walkthroughMessage, state)
            XCTAssertFalse(subject.walkthroughMessage?.contains("configuration") ?? true, state)
            XCTAssertNil(subject.error)
            XCTAssertNil(subject.walkthroughProgress)
        }
    }
    func testLegacyErrorsAndMalformedResponsesKeepUsableSourcePreview() async throws {
        for error in [APIError.http(404, "Missing"), .http(501, "Unsupported"), .http(503, "Not configured"), .decoding, .transport("Disconnected")] {
            let api = WalkthroughAPI(source: try repo())
            let subject = DetailStore(api: api)
            let loading = Task { await subject.load(try! RepoAddress("o/r")) }
            await api.waitForJob(1)
            await api.resolve(0, .failure(error))
            await loading.value
            XCTAssertNotNil(subject.preview)
            XCTAssertNil(subject.error)
            XCTAssertEqual(subject.walkthroughMessage, "Walkthrough unavailable. You can still explore the source preview.")
        }
    }
    func testPollingIsFiniteAndServerDelayIsClamped() async throws {
        let api = WalkthroughAPI(source: try repo())
        let delays = PollDelays()
        let subject = DetailStore(api: api, maximumPolls: 2, wait: { await delays.record($0) })
        let loading = Task { await subject.load(try! RepoAddress("o/r")) }
        await api.waitForJob(1); await api.resolve(0, .success(try job("queued", delay: -10)))
        await api.waitForJob(2); await api.resolve(1, .success(try job("reading", delay: Int.max)))
        await api.waitForJob(3); await api.resolve(2, .success(try job("writing")))
        await loading.value
        let recorded = await delays.values
        XCTAssertEqual(recorded, [.milliseconds(250), .milliseconds(5_000)])
        XCTAssertNotNil(subject.walkthroughMessage)
        XCTAssertNil(subject.walkthroughProgress)
        XCTAssertNotNil(subject.preview)
    }
    func testCancellationAndStaleJobCannotReplaceNewerSource() async throws {
        let api = WalkthroughAPI(source: try repo())
        let subject = DetailStore(api: api)
        let first = Task { await subject.load(try! RepoAddress("o/r")) }
        await api.waitForJob(1)
        subject.cancel()
        await api.resolve(0, .success(try job("ready", preview: repo(presentation: "walkthrough"))))
        await first.value
        XCTAssertFalse(subject.preview?.isWalkthrough ?? true)
        XCTAssertNil(subject.walkthroughProgress)
        XCTAssertNil(subject.walkthroughMessage)
        let second = Task { await subject.load(try! RepoAddress("o/r")) }
        await api.waitForJob(2)
        let third = Task { await subject.load(try! RepoAddress("o/r")) }
        await api.waitForJob(3)
        await api.resolve(2, .success(try job("failed"))); await third.value
        await api.resolve(1, .success(try job("ready", preview: repo(presentation: "walkthrough")))); await second.value
        XCTAssertFalse(subject.preview?.isWalkthrough ?? true)
        XCTAssertNotNil(subject.walkthroughMessage)
    }
    func testReadyPayloadRequiresAcceptedPresentationAndMatchingRepository() async throws {
        for preview in [try repo(), try repo(presentation: "walkthrough", slug: "other/repo")] {
            let api = WalkthroughAPI(source: try repo())
            let subject = DetailStore(api: api)
            let loading = Task { await subject.load(try! RepoAddress("o/r")) }
            await api.waitForJob(1)
            await api.resolve(0, .success(try job("ready", preview: preview)))
            await loading.value
            XCTAssertEqual(subject.preview?.slug, "o/r")
            XCTAssertFalse(subject.preview?.isWalkthrough ?? true)
            XCTAssertNotNil(subject.walkthroughMessage)
        }
    }
    func testCancellingViewTaskDuringPollWaitPreservesSourceWithoutError() async throws {
        let api = WalkthroughAPI(source: try repo())
        let subject = DetailStore(api: api)
        let loading = Task { await subject.load(try! RepoAddress("o/r")) }
        await api.waitForJob(1)
        await api.resolve(0, .success(try job("reading", delay: 5_000)))
        while subject.walkthroughProgress != "Reading the project’s sources…" { await Task.yield() }
        loading.cancel()
        await loading.value
        XCTAssertNotNil(subject.preview)
        XCTAssertNil(subject.walkthroughProgress)
        XCTAssertNil(subject.walkthroughMessage)
        XCTAssertNil(subject.error)
        let polls = await api.pollIDs
        XCTAssertTrue(polls.isEmpty)
    }
    func testPreparationDeadlineCancelsSlowRequestAndRetainsSource() async throws {
        let api = SlowWalkthroughAPI(source: try repo())
        let subject = DetailStore(api: api, maximumPolls: 8, maximumDuration: .milliseconds(10), wait: { try await Task.sleep(for: $0) })
        await subject.load(try RepoAddress("o/r"))
        XCTAssertNotNil(subject.preview)
        XCTAssertEqual(subject.walkthroughMessage, "The walkthrough is taking longer than expected. You can still explore the source preview.")
        XCTAssertNil(subject.walkthroughProgress)
        XCTAssertNil(subject.error)
    }

}

private struct SlowWalkthroughAPI: RepositoryAPI {
    let source: RepoPreview
    func feed(cursor: String?) async throws -> Feed { Feed(items: [], nextCursor: nil) }
    func preview(_ address: RepoAddress) async throws -> RepoPreview { source }
    func startWalkthrough(_ address: RepoAddress) async throws -> WalkthroughJob {
        try await Task.sleep(for: .seconds(1))
        throw APIError.invalidResponse
    }
}
