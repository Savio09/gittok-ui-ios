import Foundation

/// Keep onboarding, account and settings reachable while a bad backend address
/// is corrected. Never silently send requests to a substitute server.
public struct UnavailableRepositoryAPI: RepositoryAPI {
    public init() {}
    public func feed(cursor: String?) async throws -> Feed { throw APIError.invalidBaseURL }
    public func preview(_ address: RepoAddress) async throws -> RepoPreview { throw APIError.invalidBaseURL }
}
