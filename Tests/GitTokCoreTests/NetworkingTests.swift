import XCTest
@testable import GitTokCore

private final class StubProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) throws -> (Int, Data)
    static let lock = NSLock()
    nonisolated(unsafe) static var handlers: [String: Handler] = [:]
    static func register(_ handler: @escaping Handler) -> URL {
        let host = "\(UUID().uuidString.lowercased()).test"
        lock.withLock { handlers[host] = handler }
        return URL(string: "https://\(host)")!
    }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let handler = Self.lock.withLock { Self.handlers[request.url!.host!]! }
            let (status, data) = try handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
final class NetworkingTests: XCTestCase {
    private func client(_ handler: @escaping StubProtocol.Handler) -> APIClient {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [StubProtocol.self]
        return APIClient(baseURL: StubProtocol.register(handler), session: URLSession(configuration: config))
    }
    func testHTTPErrorBodySurvivesBoundary() async {
        let api = client { _ in (429, Data(#"{"error":"Rate limit reached"}"#.utf8)) }
        do { _ = try await api.feed(cursor: nil); XCTFail("Expected HTTP error") }
        catch { XCTAssertEqual(error as? APIError, .http(429, "Rate limit reached")) }
    }
    func testMalformedSuccessIsDecodingFailure() async {
        let api = client { _ in (200, Data("not JSON".utf8)) }
        do { _ = try await api.feed(cursor: nil); XCTFail("Expected decoding error") }
        catch { XCTAssertEqual(error as? APIError, .decoding) }
    }
    func testTimeoutIsReadable() async {
        let api = client { _ in throw URLError(.timedOut) }
        do { _ = try await api.feed(cursor: nil); XCTFail("Expected transport error") }
        catch { XCTAssertEqual(error as? APIError, .transport("The server took too long. Try again.")) }
    }
    func testOpaquePaginationCursorIsEncoded() async throws {
        let cursor = "a+/b=&?"
        let api = client { request in
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            guard components.queryItems?.first?.value == cursor else { throw APIError.invalidResponse }
            XCTAssertEqual(request.timeoutInterval, 20)
            XCTAssertEqual(request.url?.path, "/v1/feed")
            return (200, Data(#"{"items":[],"next_cursor":"next"}"#.utf8))
        }
        let page = try await api.feed(cursor: cursor)
        XCTAssertEqual(page.nextCursor, "next")
    }
    func testActualBackendFixturesDecodeAndPreserveAllSources() throws {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: Self.self)
        #endif
        let directory = try XCTUnwrap(bundle.url(forResource: "Fixtures", withExtension: nil))
        let feed = try Wire.decoder().decode(Feed.self, from: Data(contentsOf: directory.appendingPathComponent("feed.captured.json")))
        XCTAssertFalse(feed.items.isEmpty)
        let repo = try Wire.decoder().decode(RepoPreview.self, from: Data(contentsOf: directory.appendingPathComponent("preview.inferred.json")))
        let claims = (repo.sections ?? []).flatMap { $0.claims ?? [] }
        XCTAssertTrue(claims.contains { $0.status == .inferred })
        XCTAssertTrue(claims.contains { $0.allSources.count > 1 })
        XCTAssertEqual(repo.executionLabel, "Not executed")
        for name in ["preview.unknown", "preview.partial", "pocketbase__pocketbase.preview", "charmbracelet__glow.preview", "rack__rack.preview"] {
            _ = try Wire.decoder().decode(RepoPreview.self, from: Data(contentsOf: directory.appendingPathComponent(name+".json")))
        }
    }
}
