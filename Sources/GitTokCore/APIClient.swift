import Foundation

public enum APIError: LocalizedError, Equatable, Sendable {
    case invalidBaseURL, invalidRepository, invalidResponse, http(Int, String), decoding, transport(String)
    public var errorDescription: String? {
        switch self {
        case .invalidBaseURL: "Enter an HTTP or HTTPS server address without credentials, query, or fragment."
        case .invalidRepository: "Enter a GitHub repository as owner/repository."
        case .invalidResponse: "The server returned an invalid response."
        case .http(let code, let message): "Server error \(code): \(message)"
        case .decoding: "The server response could not be read. Check that this backend supports GitTok’s preview API."
        case .transport(let message): message
        }
    }
}
public protocol RepositoryAPI: Sendable {
    func feed(cursor: String?) async throws -> Feed
    func preview(_ address: RepoAddress) async throws -> RepoPreview
}
public struct APIClient: RepositoryAPI, Sendable {
    public let baseURL: URL
    private let session: URLSession
    public init(baseURL: URL, session: URLSession? = nil) {
        self.baseURL = baseURL
        if let session { self.session = session } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 20
            configuration.timeoutIntervalForResource = 30
            self.session = URLSession(configuration: configuration)
        }
    }
    public static func validatedBaseURL(_ value: String) throws -> URL {
        guard let url = SafeURL.link(value.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.query == nil, url.fragment == nil else { throw APIError.invalidBaseURL }
        return url
    }
    public func feed(cursor: String?) async throws -> Feed {
        var components = URLComponents(url: baseURL.appendingPathComponent("v1/feed"), resolvingAgainstBaseURL: false)!
        if let cursor, !cursor.isEmpty { components.queryItems = [URLQueryItem(name: "cursor", value: cursor)] }
        return try await get(components.url!)
    }
    public func preview(_ address: RepoAddress) async throws -> RepoPreview {
        try await get(baseURL.appendingPathComponent("v1/repos").appendingPathComponent(address.owner).appendingPathComponent(address.name).appendingPathComponent("preview"))
    }
    // Apple async URL loading: https://developer.apple.com/documentation/foundation/urlsession/data(for:delegate:)
    private struct ErrorBody: Decodable { let error: String }
    private func get<T: Decodable & Sendable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let data: Data, response: URLResponse
        do { (data, response) = try await session.data(for: request) }
        catch {
            if Task.isCancelled || (error as? URLError)?.code == .cancelled { throw CancellationError() }
            throw APIError.transport((error as? URLError)?.code == .timedOut ? "The server took too long. Try again." : "Could not reach the backend. Check its address and that the server is running.")
        }
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(response.statusCode) else {
            let message = (try? JSONDecoder().decode(ErrorBody.self, from: data).error) ?? "Request failed. Try again."
            throw APIError.http(response.statusCode, String(message.prefix(400)))
        }
        guard data.count <= 8 * 1024 * 1024 else { throw APIError.invalidResponse }
        do { return try Wire.decoder().decode(T.self, from: data) }
        catch { throw APIError.decoding }
    }
}
