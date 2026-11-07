import Foundation

/// Reviewed presentation facts; narration remains owned by the claim's supports field.
public struct StoryVisual: Codable, Equatable, Sendable {
    public let kind: String
    public let title: String
    public let lines: [String]
    public let focus: Int
    public let cue: String
}

public struct StoryboardBeat: Codable, Equatable, Sendable {
    public let id: String
    public let claimId: String
}

public struct Storyboard: Codable, Equatable, Sendable {
    public let version: Int
    public let beats: [StoryboardBeat]
}

public struct ResolvedStoryBeat: Identifiable, Sendable {
    public let id: String
    public let claim: Claim
    public let narration: String
    public let visual: StoryVisual
    public let evidenceID: String
    public let sceneID: String
    public let sceneTitle: String
    public let sceneKind: String
    /// First literal cue position, in the units used by AVSpeechSynthesizer callbacks.
    public var cueUTF16Offset: Int {
        guard let range = narration.range(of: visual.cue, options: .literal) else { return NSNotFound }
        return NSRange(range, in: narration).location
    }
    /// Word callbacks announce the range about to be spoken. A skipped callback can
    /// still reveal a cue already passed; empty, unavailable and overflowing ranges cannot.
    public func shouldRevealVisual(for spokenRange: NSRange) -> Bool {
        guard spokenRange.location != NSNotFound, spokenRange.location >= 0, spokenRange.length > 0,
              cueUTF16Offset != NSNotFound else { return false }
        let (end, overflow) = spokenRange.location.addingReportingOverflow(spokenRange.length)
        return !overflow && end > cueUTF16Offset
    }
}

extension RepoPreview {
    /// Resolve the complete film or preserve the ordinary readable preview. Never
    /// compactMap invalid references: doing so would silently change the accepted story.
    public var storyboardBeats: [ResolvedStoryBeat]? {
        guard isWalkthrough, evidenceMode == "not_executed" else { return nil }
        let pages = previewPages
        guard !pages.isEmpty, media == nil, pages.count == (sections ?? []).count,
              (sections ?? []).allSatisfy({ $0.storyboard != nil }) else { return nil }
        var beatIDs: Set<String> = []
        var claimIDs: Set<String> = []
        var resolved: [ResolvedStoryBeat] = []
        for page in pages {
            guard page.evidenceMode == "not_executed", page.media == nil,
                  let storyboard = page.storyboard, storyboard.version == 1, !storyboard.beats.isEmpty,
                  storyboard.beats.count == page.claims.count, page.evidenceIDs.count == page.claims.count else { return nil }
            for (index, beat) in storyboard.beats.enumerated() {
                let claim = page.claims[index]
                guard !beat.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      beatIDs.insert(beat.id).inserted,
                      let claimID = claim.id, !claimID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      claimIDs.insert(claimID).inserted, beat.claimId == claimID,
                      let narration = claim.supports, !narration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      let visual = claim.visual, visual.isValid(for: claim, narration: narration) else { return nil }
                resolved.append(ResolvedStoryBeat(id: beat.id, claim: claim, narration: narration, visual: visual,
                                                 evidenceID: page.evidenceIDs[index], sceneID: page.id,
                                                 sceneTitle: page.title, sceneKind: page.kind))
            }
        }
        return resolved.isEmpty ? nil : resolved
    }
}

private extension StoryVisual {
    func isValid(for claim: Claim, narration: String) -> Bool {
        guard validVisualText(cue, maximum: 40),
              narration.range(of: cue, options: .literal) != nil,
              focus >= 0, focus <= lines.count else { return false }
        if kind == "source" {
            // Published code comes from the actual first citation. Code retains
            // indentation and long original lines rather than model prose limits.
            guard title == claim.source.ref, (1...6).contains(lines.count),
                  lines.joined(separator: "\n").utf8.count <= 2_400,
                  let excerpt = claim.excerpt else { return false }
            return lines == Array(excerpt.components(separatedBy: "\n").prefix(lines.count))
        }
        guard validVisualText(title, maximum: 56),
              lines.allSatisfy({ validVisualText($0, maximum: 80) }) else { return false }
        switch kind {
        case "concept": return (1...3).contains(lines.count)
        case "terminal": return (1...4).contains(lines.count)
        case "flow": return (2...4).contains(lines.count)
        case "comparison": return lines.count == 2
        default: return false
        }
    }
}

/// Match the producer's required, bounded text and Unicode Cc control check.
/// Format scalars, including emoji joiners, remain part of the reviewed wording.
private func validVisualText(_ text: String, maximum: Int) -> Bool {
    let scalars = text.unicodeScalars
    return scalars.count <= maximum && scalars.contains(where: { !$0.properties.isWhitespace })
        && scalars.allSatisfy({ $0.properties.generalCategory != .control })
}
