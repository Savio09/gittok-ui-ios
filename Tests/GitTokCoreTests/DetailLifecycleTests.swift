import XCTest
@testable import GitTokCore

private actor TabPreviewAPI: RepositoryAPI {
    private(set) var previews = 0
    private(set) var starts = 0
    private let failSecondSource: Bool
    init(failSecondSource: Bool = false) { self.failSecondSource = failSecondSource }
    func feed(cursor: String?) async throws -> Feed { Feed(items: [], nextCursor: nil) }
    func preview(_ address: RepoAddress) async throws -> RepoPreview {
        previews += 1
        if failSecondSource && previews == 2 { throw URLError(.badServerResponse) }
        return try Wire.decoder().decode(RepoPreview.self, from: Data(#"{"id":"o/r","owner":"o","name":"r","slug":"o/r","kind":"other","description":"D","github_url":"https://github.com/o/r"}"#.utf8))
    }
    func startWalkthrough(_ address: RepoAddress) async throws -> WalkthroughJob {
        starts += 1
        return try Wire.decoder().decode(WalkthroughJob.self, from: Data(#"{"id":"bounded","state":"failed"}"#.utf8))
    }
}
@MainActor final class DetailLifecycleTests: XCTestCase {
    func testReturningToRetainedSourcePreviewDoesNotSubmitAnotherWalkthrough() async throws {
        let api = TabPreviewAPI(); let store = DetailStore(api: api)
        let address = try RepoAddress("o/r")
        await store.loadIfNeeded(address)
        store.cancel()
        await store.loadIfNeeded(address)
        let starts = await api.starts; let previews = await api.previews
        XCTAssertEqual(starts, 1)
        XCTAssertEqual(previews, 1)
        XCTAssertNotNil(store.walkthroughMessage)
    }
}

private actor PendingTabAPI: RepositoryAPI {
    private(set) var starts = 0
    private var started = false
    private var ready: CheckedContinuation<Void, Never>?
    private var response: CheckedContinuation<WalkthroughJob, any Error>?
    func feed(cursor: String?) async throws -> Feed { Feed(items: [], nextCursor: nil) }
    func preview(_ address: RepoAddress) async throws -> RepoPreview { try Wire.decoder().decode(RepoPreview.self, from: Data(#"{"id":"o/r","owner":"o","name":"r","slug":"o/r","kind":"other","description":"D","github_url":"https://github.com/o/r"}"#.utf8)) }
    func startWalkthrough(_ address: RepoAddress) async throws -> WalkthroughJob {
        starts += 1
        return try await withCheckedThrowingContinuation { continuation in
            response = continuation; started = true; ready?.resume(); ready = nil
        }
    }
    func waitForStart() async { if !started { await withCheckedContinuation { ready = $0 } } }
    func resolve() throws {
        response?.resume(returning: try Wire.decoder().decode(WalkthroughJob.self, from: Data(#"{"id":"pending","state":"queued"}"#.utf8))); response = nil
    }
}
@MainActor extension DetailLifecycleTests {
    func testTerminalSourceFailureOnRetryDoesNotBecomeAutomaticPaidRetry() async throws {
        let api = TabPreviewAPI(failSecondSource: true); let store = DetailStore(api: api)
        let address = try RepoAddress("o/r")
        await store.loadIfNeeded(address)
        await store.load(address)
        XCTAssertNotNil(store.error)
        store.cancel(); await store.loadIfNeeded(address)
        let starts = await api.starts; let previews = await api.previews
        XCTAssertEqual(starts, 1); XCTAssertEqual(previews, 2)
        XCTAssertNotNil(store.error)
    }
    func testPendingPreparationKeepsResumeForEitherCancellationOrdering() async throws {
        for frameworkCancelsFirst in [true, false] {
            let api = PendingTabAPI(); let store = DetailStore(api: api)
            let address = try RepoAddress("o/r")
            let loading = Task { await store.loadIfNeeded(address) }
            await api.waitForStart()
            if !frameworkCancelsFirst { store.cancel() }
            loading.cancel(); try await api.resolve(); await loading.value
            if frameworkCancelsFirst { store.cancel() }
            await store.loadIfNeeded(address)
            let starts = await api.starts
            XCTAssertEqual(starts, 1)
            XCTAssertNotNil(store.preview)
            XCTAssertTrue(store.preparationPaused, "Framework cancels first: \(frameworkCancelsFirst)")
        }
    }
}

private actor InterruptedSourceAPI: RepositoryAPI {
    let suspendAt: Int
    private(set) var previews = 0
    private(set) var starts = 0
    private var ready: CheckedContinuation<Void, Never>?
    private var suspended = false
    private var response: CheckedContinuation<RepoPreview, any Error>?
    init(suspendAt: Int) { self.suspendAt = suspendAt }
    func feed(cursor: String?) async throws -> Feed { Feed(items: [], nextCursor: nil) }
    private func repo() throws -> RepoPreview { try Wire.decoder().decode(RepoPreview.self, from: Data(#"{"id":"o/r","owner":"o","name":"r","slug":"o/r","kind":"other","description":"D","github_url":"https://github.com/o/r"}"#.utf8)) }
    func preview(_ address: RepoAddress) async throws -> RepoPreview {
        previews += 1
        if previews != suspendAt { return try repo() }
        return try await withCheckedThrowingContinuation { response = $0; suspended = true; ready?.resume(); ready = nil }
    }
    func waitForSource() async { if !suspended { await withCheckedContinuation { ready = $0 } } }
    func resolve() throws { response?.resume(returning: try repo()); response = nil }
    func startWalkthrough(_ address: RepoAddress) async throws -> WalkthroughJob {
        starts += 1
        return try Wire.decoder().decode(WalkthroughJob.self, from: Data(#"{"id":"failed","state":"failed"}"#.utf8))
    }
}
@MainActor extension DetailLifecycleTests {
    func testInterruptedInitialAndRetrySourceRequestsRequireAnExplicitRetry() async throws {
        for suspendAt in [1, 2] {
            for frameworkCancelsFirst in [true, false] {
                let api = InterruptedSourceAPI(suspendAt: suspendAt); let store = DetailStore(api: api)
                let address = try RepoAddress("o/r")
                if suspendAt == 2 { await store.loadIfNeeded(address) }
                let loading = Task { await store.load(address) }
                await api.waitForSource()
                if !frameworkCancelsFirst { store.cancel() }
                loading.cancel(); try await api.resolve(); await loading.value
                if frameworkCancelsFirst { store.cancel() }
                await store.loadIfNeeded(address)
                let starts = await api.starts; let previews = await api.previews
                XCTAssertEqual(starts, suspendAt - 1)
                XCTAssertEqual(previews, suspendAt)
                XCTAssertNotNil(store.error)
            }
        }
    }
}
