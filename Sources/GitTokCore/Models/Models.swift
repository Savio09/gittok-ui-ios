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
    public let id: String?
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
    public let visual: StoryVisual?
    public var status: EvidenceStatus { evidenceStatus ?? .unknown }
    public var allSources: [Source] { [source] + (additionalSources ?? []) }
    private enum CodingKeys: String, CodingKey {
        case id, label, source, additionalSources, excerpt, explanation, supports, limit, confidence, stance, evidenceStatus, visual
    }
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(String.self, forKey: .id)
        label = try values.decode(String.self, forKey: .label)
        source = try values.decode(Source.self, forKey: .source)
        additionalSources = try values.decodeIfPresent([Source].self, forKey: .additionalSources)
        excerpt = try values.decodeIfPresent(String.self, forKey: .excerpt)
        explanation = try values.decode(String.self, forKey: .explanation)
        supports = try values.decodeIfPresent(String.self, forKey: .supports)
        limit = try values.decodeIfPresent(String.self, forKey: .limit)
        confidence = try values.decodeIfPresent(String.self, forKey: .confidence)
        stance = try values.decodeIfPresent(String.self, forKey: .stance)
        evidenceStatus = try values.decodeIfPresent(EvidenceStatus.self, forKey: .evidenceStatus)
        // Additive presentation data must never make the accepted evidence unreadable.
        visual = try? values.decodeIfPresent(StoryVisual.self, forKey: .visual)
    }
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
    public let id: String?
    public let media: PreviewMedia?
    public let kind: String
    public let title: String
    public let body: String?
    public let claims: [Claim]?
    public let evidenceMode: String?
    public let storyboard: Storyboard?
    private enum CodingKeys: String, CodingKey {
        case id, media, kind, title, body, claims, evidenceMode, storyboard
    }
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(String.self, forKey: .id)
        media = try values.decodeIfPresent(PreviewMedia.self, forKey: .media)
        kind = try values.decode(String.self, forKey: .kind)
        title = try values.decode(String.self, forKey: .title)
        body = try values.decodeIfPresent(String.self, forKey: .body)
        claims = try values.decodeIfPresent([Claim].self, forKey: .claims)
        evidenceMode = try values.decodeIfPresent(String.self, forKey: .evidenceMode)
        storyboard = try? values.decodeIfPresent(Storyboard.self, forKey: .storyboard)
    }
}
public struct RepoPreview: Codable, Identifiable, Sendable {
    public let presentation: String?
    public var isWalkthrough: Bool { presentation == "walkthrough" }
    public let media: PreviewMedia?
    public let fit: PreviewFit?
    public let signals: [PreviewSignal]?
    public let id: String
    public let githubId: Int64?
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
/// Background preparation never changes the provenance of its preview.
public struct WalkthroughJob: Codable, Sendable {
    public let id: String
    public let state: String
    public let stage: String?
    public let pollAfterMs: Int?
    public let preview: RepoPreview?
    public let message: String?
    public var isPending: Bool { ["queued", "reading", "writing", "reviewing"].contains(state) }
    public var pollingDelay: Duration { .milliseconds(min(5_000, max(250, pollAfterMs ?? 1_000))) }
    public var progressLabel: String {
        switch state {
        case "reading": "Reading the project’s sources…"
        case "writing": "Preparing the walkthrough…"
        case "reviewing": "Checking the walkthrough’s sources…"
        default: "Preparing the walkthrough…"
        }
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
