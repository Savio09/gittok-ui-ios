import Foundation

public enum MediaRenderingKind: Equatable, Sendable { case image, video, unsupported }

public struct PreviewMedia: Codable, Sendable {
    public let kind: String
    public let evidenceMode: String?
    public let caption: String?
    public let url: String?
    public var safeURL: URL? { SafeURL.link(url) }
    public var renderingKind: MediaRenderingKind {
        switch kind.lowercased() {
        case "image", "screenshot", "diagram", "poster": .image
        case "video", "clip", "narrated_video", "demo": .video
        default: .unsupported
        }
    }
}
public struct PreviewFit: Codable, Sendable {
    public let summary: String?
    public let dimensions: [FitDimension]?
}
public struct FitDimension: Codable, Sendable {
    public let name: String
    public let level: Int
    public let word: String
}
public struct PreviewSignal: Codable, Sendable {
    public let value: String
    public let reason: String
}

public struct EvidenceEntry: Identifiable, Sendable {
    public let id: String
    public let claim: Claim
    public let sectionTitle: String
    public let evidenceMode: String?
}

/// One available content item, not a fixed position in a three-slide template.
public struct PreviewPage: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let body: String
    public let kind: String
    public let claims: [Claim]
    public let media: PreviewMedia?
    public let evidenceMode: String?
}

extension RepoPreview {
    public var evidenceEntries: [EvidenceEntry] {
        (sections ?? []).enumerated().flatMap { sectionIndex, section in
            (section.claims ?? []).enumerated().map { claimIndex, claim in
                EvidenceEntry(id: "\(slug.lowercased())|\(sectionIndex)|\(claimIndex)|\(claim.source.ref)|\(claim.source.lines ?? "")", claim: claim, sectionTitle: section.title, evidenceMode: section.evidenceMode)
            }
        }
    }
    public var previewPages: [PreviewPage] {
        var pages: [PreviewPage] = []
        if let media {
            pages.append(PreviewPage(id: "\(slug)|media", title: media.caption?.isEmpty == false ? media.caption! : "Project preview", body: "", kind: "media", claims: [], media: media, evidenceMode: media.evidenceMode))
        }
        let contentSections = (sections ?? []).enumerated().filter { _, section in
            section.media != nil || (!["activity", "decision"].contains(section.kind) && (!(section.body ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !(section.claims ?? []).isEmpty))
        }
        if !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !contentSections.contains(where: { $0.element.kind == "idea" }) {
            pages.append(PreviewPage(id: "\(slug)|description", title: headline?.isEmpty == false ? headline! : name, body: description, kind: "idea", claims: [], media: nil, evidenceMode: "not_executed"))
        }
        for (index, section) in contentSections {
            pages.append(PreviewPage(id: "\(slug)|section|\(index)", title: section.title, body: section.body ?? "", kind: section.kind, claims: section.claims ?? [], media: section.media, evidenceMode: section.media != nil ? section.media?.evidenceMode : section.evidenceMode))
        }
        return pages
    }
    public var starCount: String? { metrics?.first(where: { $0.key == "stars" })?.value }
    public var sourceCount: Int { Set(evidenceEntries.flatMap { $0.claim.allSources }.map { "\($0.ref)|\($0.lines ?? "")|\($0.url ?? "")" }).count }
}
