import XCTest
@testable import GitTokCore

private actor SearchAPI: RepositoryAPI {
    var requests: [(String, String?)] = []
    var waiters: [Int: CheckedContinuation<Feed, any Error>] = [:]
    func feed(cursor: String?) async throws -> Feed { XCTFail("Search must not use the feed"); return Feed(items: [], nextCursor: nil) }
    func preview(_ address: RepoAddress) async throws -> RepoPreview { throw APIError.invalidResponse }
    func search(query: String, cursor: String?) async throws -> Feed {
        let index = requests.count; requests.append((query, cursor))
        return try await withCheckedThrowingContinuation { waiters[index] = $0 }
    }
    func wait(_ count: Int) async { while requests.count < count { await Task.yield() } }
    func resolve(_ index: Int, _ result: Result<Feed, any Error>) { waiters.removeValue(forKey: index)!.resume(with: result) }
    func count() -> Int { requests.count }
}

@MainActor final class RepositorySearchTests: XCTestCase {
    private func repo(_ name: String) throws -> RepoPreview {
        try Wire.decoder().decode(RepoPreview.self, from: Data("{\"id\":\"outside/\(name)\",\"owner\":\"outside\",\"name\":\"\(name)\",\"slug\":\"outside/\(name)\",\"kind\":\"other\",\"description\":\"A public project\",\"github_url\":\"https://github.com/outside/\(name)\"}".utf8))
    }
    func testRemoteResultsDoNotDependOnLoadedFeed() async throws {
        let api = SearchAPI(); let store = RepositorySearchStore(api: api, debounce: .zero)
        store.query = "older project"
        let task = Task { await store.performRequest() }; await api.wait(1)
        await api.resolve(0, .success(Feed(items: [try repo("older")], nextCursor: nil))); await task.value
        XCTAssertEqual(store.items.map(\.slug), ["outside/older"])
        XCTAssertTrue(store.hasSearched); XCTAssertNil(store.error)
    }
    func testEditingAndClearingInvalidateOldResponseBeforeNextRequestStarts() async throws {
        let api = SearchAPI(); let store = RepositorySearchStore(api: api, debounce: .zero)
        store.query = "old"
        let old = Task { await store.performRequest() }; await api.wait(1)
        store.query = "new"
        await api.resolve(0, .success(Feed(items: [try repo("old")], nextCursor: "old-page"))); await old.value
        XCTAssertTrue(store.items.isEmpty); XCTAssertNil(store.nextCursor)
        let newer = Task { await store.performRequest() }; await api.wait(2)
        store.query = ""
        await api.resolve(1, .success(Feed(items: [try repo("new")], nextCursor: nil))); await newer.value
        XCTAssertTrue(store.items.isEmpty); XCTAssertFalse(store.isLoading); XCTAssertFalse(store.hasSearched)
    }
    func testFailedPageRetainsResultsAndRetriesSameCursor() async throws {
        let api = SearchAPI(); let store = RepositorySearchStore(api: api, debounce: .zero)
        store.query = "project"
        let first = Task { await store.performRequest() }; await api.wait(1)
        let item = try repo("one")
        await api.resolve(0, .success(Feed(items: [item], nextCursor: "page2"))); await first.value
        store.requestMore()
        let more = Task { await store.performRequest() }; await api.wait(2)
        await api.resolve(1, .failure(APIError.http(503, "Try later"))); await more.value
        XCTAssertEqual(store.items.count, 1); XCTAssertEqual(store.nextCursor, "page2"); XCTAssertNotNil(store.error)
        store.retry()
        let retry = Task { await store.performRequest() }; await api.wait(3)
        await api.resolve(2, .success(Feed(items: [item, try repo("two")], nextCursor: "page2"))); await retry.value
        XCTAssertEqual(store.items.map(\.slug), ["outside/one", "outside/two"])
        XCTAssertNil(store.nextCursor); XCTAssertNil(store.error)
        let requests = await api.requests
        XCTAssertEqual(requests.map { $0.1 }, [nil, "page2", "page2"])
    }
    func testDismissalRejectsLateResultWithoutShowingError() async throws {
        let api = SearchAPI(); let store = RepositorySearchStore(api: api, debounce: .zero)
        store.query = "project"
        let task = Task { await store.performRequest() }; await api.wait(1)
        store.cancel()
        await api.resolve(0, .success(Feed(items: [try repo("late")], nextCursor: nil))); await task.value
        XCTAssertTrue(store.items.isEmpty); XCTAssertFalse(store.isLoading); XCTAssertNil(store.error)
    }
    func testEmptyQueryDoesNotUseNetworkAndSuccessfulEmptyIsExplicit() async {
        let api = SearchAPI(); let store = RepositorySearchStore(api: api, debounce: .zero)
        await store.performRequest()
        let count = await api.count(); XCTAssertEqual(count, 0)
        store.query = "no matches"
        let task = Task { await store.performRequest() }; await api.wait(1)
        await api.resolve(0, .success(Feed(items: [], nextCursor: nil))); await task.value
        XCTAssertTrue(store.items.isEmpty); XCTAssertTrue(store.hasSearched); XCTAssertNil(store.error)
    }
    func testEmptyKeyboardSubmissionDoesNotLeaveLoadingActive() async {
        let api = SearchAPI(); let store = RepositorySearchStore(api: api, debounce: .zero)
        for query in ["", "   "] {
            store.query = query; store.retry(); await store.performRequest()
            XCTAssertFalse(store.isLoading); XCTAssertFalse(store.isLoadingMore)
        }
        let count = await api.count(); XCTAssertEqual(count, 0)
    }
    func testReopeningInterruptedPaginationRestoresLoadingProtection() async throws {
        let api = SearchAPI(); let store = RepositorySearchStore(api: api, debounce: .zero)
        store.query = "project"
        let first = Task { await store.performRequest() }; await api.wait(1)
        await api.resolve(0, .success(Feed(items: [try repo("one")], nextCursor: "page2"))); await first.value
        store.requestMore()
        let interrupted = Task { await store.performRequest() }; await api.wait(2)
        store.cancel()
        let reopened = Task { await store.performRequest() }; await api.wait(3)
        XCTAssertTrue(store.isLoadingMore)
        let id = store.requestID; store.requestMore(); XCTAssertEqual(store.requestID, id)
        await api.resolve(1, .success(Feed(items: [try repo("late")], nextCursor: nil))); await interrupted.value
        await api.resolve(2, .success(Feed(items: [try repo("two")], nextCursor: nil))); await reopened.value
        XCTAssertEqual(store.items.map(\.slug), ["outside/one", "outside/two"])
        XCTAssertFalse(store.isLoadingMore)
    }
}
