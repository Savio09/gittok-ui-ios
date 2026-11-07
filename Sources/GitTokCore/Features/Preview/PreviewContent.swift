import Foundation
import CryptoKit

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
        case "video", "clip", "narrated_video": .video
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
    public let sectionKind: String
    public let sectionID: String
    public let evidenceMode: String?
}

/// One available content item, not a fixed position in a three-slide template.
public struct PreviewPage: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let body: String
    public let kind: String
    public let claims: [Claim]
    public let evidenceIDs: [String]
    public let media: PreviewMedia?
    public let evidenceMode: String?
    public let storyboard: Storyboard?
}

extension RepoPreview {
    public var evidenceEntries: [EvidenceEntry] {
        var occurrences: [String: Int] = [:]
        return identifiedSections.flatMap { identified in
            let section = identified.section
            return (section.claims ?? []).map { claim in
                let base = claim.id.map { contentID([slug.lowercased(), identified.id, $0]) } ?? contentID([slug.lowercased(), section.kind, section.title, section.body ?? "", section.evidenceMode ?? "", claimKey(claim)])
                let occurrence = occurrences[base, default: 0]; occurrences[base] = occurrence + 1
                return EvidenceEntry(id: "\(base)|\(occurrence)", claim: claim, sectionTitle: section.title, sectionKind: section.kind, sectionID: identified.id, evidenceMode: section.evidenceMode)
            }
        }
    }
    public var previewPages: [PreviewPage] {
        var pages: [PreviewPage] = []
        let entries = Dictionary(grouping: evidenceEntries, by: \.sectionID)
        if let media {
            pages.append(PreviewPage(id: contentID([slug.lowercased(), "media"] + mediaKey(media)), title: media.caption?.isEmpty == false ? media.caption! : "Project preview", body: "", kind: "media", claims: [], evidenceIDs: [], media: media, evidenceMode: nil, storyboard: nil))
        }
        let contentSections = identifiedSections.filter { identified in
            let section = identified.section
            return section.media != nil || (section.kind != "decision" && (!(section.body ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !(section.claims ?? []).isEmpty))
        }
        let descriptionIsPresent = contentSections.contains { $0.section.kind == "idea" && $0.section.body?.trimmingCharacters(in: .whitespacesAndNewlines) == description.trimmingCharacters(in: .whitespacesAndNewlines) }
        if !isWalkthrough && !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !descriptionIsPresent {
            pages.append(PreviewPage(id: contentID([slug.lowercased(), "description", description]), title: headline?.isEmpty == false ? headline! : name, body: description, kind: "idea", claims: [], evidenceIDs: [], media: nil, evidenceMode: "not_executed", storyboard: nil))
        }
        for identified in contentSections {
            let section = identified.section
            pages.append(PreviewPage(id: identified.id, title: section.title, body: section.body ?? "", kind: section.kind, claims: section.claims ?? [], evidenceIDs: (entries[identified.id] ?? []).map(\.id), media: section.media, evidenceMode: section.evidenceMode, storyboard: section.storyboard))
        }
        return pages
    }
    private var identifiedSections: [(id: String, section: PreviewSection)] {
        var occurrences: [String: Int] = [:]
        return (sections ?? []).map { section in
            let key = [slug.lowercased(), section.kind, section.title, section.body ?? "", section.evidenceMode ?? ""] + (section.claims ?? []).map(claimKey) + (section.media.map(mediaKey) ?? []) + (section.storyboard.map(storyboardKey) ?? [])
            let base = section.id.map { contentID([slug.lowercased(), "section", $0]) } ?? contentID(key)
            let occurrence = occurrences[base, default: 0]; occurrences[base] = occurrence + 1
            return (id: "\(base)|\(occurrence)", section: section)
        }
    }
    public var setupSection: PreviewSection? {
        (sections ?? []).first { $0.kind == "setup" && !($0.claims ?? []).isEmpty }
            ?? (sections ?? []).first { $0.kind == "setup" && !($0.body ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    public var starCount: String? { metrics?.first(where: { $0.key == "stars" })?.value }
    public var sourceCount: Int { Set(evidenceEntries.flatMap { $0.claim.allSources }.map { "\($0.ref)|\($0.lines ?? "")|\($0.url ?? "")" }).count }
}

private func mediaKey(_ media: PreviewMedia) -> [String] { [media.kind, media.url ?? "", media.caption ?? "", media.evidenceMode ?? ""] }
private func claimKey(_ claim: Claim) -> String {
    let fields = [claim.label, claim.explanation, claim.excerpt ?? "", claim.supports ?? "", claim.limit ?? "", claim.status.rawValue, claim.confidence ?? "", claim.stance ?? ""] + claim.allSources.flatMap { [$0.kind ?? "", $0.ref, $0.lines ?? "", $0.url ?? ""] } + (claim.visual.map(visualKey) ?? [])
    return contentID(fields)
}
private func visualKey(_ visual: StoryVisual) -> [String] {
    ["visual", visual.kind, visual.title, String(visual.focus), visual.cue] + visual.lines
}
private func storyboardKey(_ storyboard: Storyboard) -> [String] {
    ["storyboard", String(storyboard.version)] + storyboard.beats.flatMap { [$0.id, $0.claimId] }
}
/// Length-prefixed fields give deterministic, unambiguous content identities.
private func contentID(_ fields: [String]) -> String {
    let key = fields.map { "\($0.utf8.count):\($0)" }.joined()
    return SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
}
