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
