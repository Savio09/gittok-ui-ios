import Foundation

public enum EvidenceStatus: String, Codable, Sendable {
    case supported, inferred, unknown
    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: raw) ?? .unknown
    }
    public var title: String { rawValue.capitalized }
}

public struct Source: Codable, Hashable, Sendable {
    public let kind: String?
    public let ref: String
    public let lines: String?
    public let url: String?
}
public struct Claim: Codable, Sendable {
    public let label: String
    public let source: Source
    public let additionalSources: [Source]?
    public let excerpt: String?
    public let explanation: String
    public let supports: String?
    public let limit: String?
    public let confidence: String?
    public let stance: String?
    public let evidenceStatus: EvidenceStatus?
    public var status: EvidenceStatus { evidenceStatus ?? .unknown }
    public var allSources: [Source] { [source] + (additionalSources ?? []) }
}
public struct Metric: Codable, Sendable {
    public let key: String
    public let label: String
    public let value: String
    public let source: Source?
    public let confidence: String?
    public let evidenceStatus: EvidenceStatus?
    public var status: EvidenceStatus { evidenceStatus ?? .unknown }
}
public struct PreviewSection: Codable, Sendable {
    public let kind: String
    public let title: String
    public let body: String?
    public let claims: [Claim]?
    public let evidenceMode: String?
}
public struct RepoPreview: Codable, Identifiable, Sendable {
    public let id: String
    public let owner: String
    public let name: String
    public let slug: String
    public let kind: String
    public let language: String?
    public let headline: String?
    public let description: String
    public let githubUrl: String
    public let license: String?
    public let metrics: [Metric]?
    public let sections: [PreviewSection]?
    public let kindEvidenceStatus: EvidenceStatus?
    public let evidenceMode: String?
    public var kindStatus: EvidenceStatus { kindEvidenceStatus ?? .unknown }
    public var kindTitle: String {
        switch kind {
        case "frontend": "Frontend"
        case "backend": "Backend"
        case "library": "Library"
        case "cli": "Command line"
        case "mobile": "Mobile"
        default: "Unclassified"
        }
    }
    public var executionLabel: String {
        ExecutionEvidence.label(for: evidenceMode)
    }
}
public struct Feed: Codable, Sendable {
    public let items: [RepoPreview]
    public let nextCursor: String?
}
public enum Wire {
    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}
public struct RepoAddress: Hashable, Sendable {
    public let owner: String
    public let name: String
    public var slug: String { "\(owner)/\(name)" }
    public init(_ value: String) throws {
        let parts = value.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2 else { throw APIError.invalidRepository }
        let owner = String(parts[0]), name = String(parts[1])
        let ownerChars = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-")
        let repoChars = ownerChars.union(CharacterSet(charactersIn: "._"))
        guard !owner.isEmpty, owner.count <= 39, !name.isEmpty, name.count <= 100,
              owner.unicodeScalars.allSatisfy(ownerChars.contains), name.unicodeScalars.allSatisfy(repoChars.contains),
              name != ".", name != ".." else { throw APIError.invalidRepository }
        self.owner = owner; self.name = name
    }
}
public enum SafeURL {
    public static func link(_ value: String?) -> URL? {
        guard let value, let url = URL(string: value),
              ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
              let host = url.host, !host.isEmpty, url.user == nil, url.password == nil else { return nil }
        return url
    }
}

/// Execution knowledge is independent of confidence and evidence status.
public enum ExecutionEvidence {
    public static func label(for mode: String?) -> String {
        switch mode {
        case "not_executed": "Not executed"
        case "observed_running": "Observed running"
        default: "Execution unknown"
        }
    }
}
