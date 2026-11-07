import SwiftUI
import AVKit
import Combine
import GitTokCore

struct PreviewPlayer: View {
    let repo: RepoPreview
    let onEvidence: (String?) -> Void
    var active = true
    @State private var selected = 0
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var pages: [PreviewPage] { repo.previewPages }
    private var index: Int { min(selected, max(0, pages.count - 1)) }
    var body: some View {
        if let beats = repo.storyboardBeats {
            StoryboardPlayer(beats: beats, active: active, onEvidence: onEvidence).id(storyIdentity(beats))
        } else if pages.isEmpty {
            StateMessage(title: "A preview is not available yet", message: "Explore the available repository facts and sources below.", symbol: "doc.text.image").padding(20)
        } else {
            let page = pages[index]
            VStack(alignment: .leading, spacing: 14) {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 5) {
                            ForEach(Array(pages.enumerated()), id: \.element.id) { position, item in
                                Button { selected = position } label: {
                                    Capsule().fill(position <= index ? Folio.tint(for: repo.kind) : Folio.paper.opacity(0.25)).frame(width: max(30, min(90, 300 / CGFloat(pages.count))), height: 3).frame(minWidth: 44, minHeight: 44)
                                }.id(item.id).accessibilityLabel("Preview segment \(position + 1) of \(pages.count)").accessibilityAddTraits(position == index ? .isSelected : [])
                            }
                        }
                    }.onChange(of: index) { _, _ in withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { proxy.scrollTo(pages[index].id, anchor: .center) } }
                }
                if let media = page.media {
                    PreviewArtifact(media: media, active: active && scenePhase == .active).id(page.id)
                    Label(ExecutionEvidence.label(for: media.evidenceMode), systemImage: media.evidenceMode == "observed_running" ? "play.rectangle" : "info.circle")
                        .font(.caption2).foregroundStyle(Folio.paper.opacity(0.85)).accessibilityIdentifier("preview.media-mode")
                } else if repo.isWalkthrough {
                    WalkthroughScene(page: page)
                } else { SourceOverview(repo: repo, page: page) }
                VStack(alignment: .leading, spacing: 10) {
                    Text(String(format: "%02d / %@", index + 1, page.media == nil ? "SOURCE STORY" : "PREVIEW")).font(.system(size: 9, weight: .medium)).tracking(1.2).foregroundStyle(Folio.paper.opacity(0.8))
                    Text(page.title).font(Folio.serif(28)).foregroundStyle(Folio.paper).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("preview.title")
                    if !page.body.isEmpty && (!repo.isWalkthrough || page.media != nil) { Text(page.body).font(.footnote).foregroundStyle(Folio.paper.opacity(0.85)).fixedSize(horizontal: false, vertical: true) }
                    if !page.claims.isEmpty {
                        VStack(alignment: .leading, spacing: 7) {
                            if !repo.isWalkthrough {
                                ForEach(Array(page.claims.prefix(2).enumerated()), id: \.offset) { _, claim in
                                    Label(claim.label, systemImage: "link").font(.footnote).foregroundStyle(Folio.paper.opacity(0.9))
                                }
                            }
                            Button { onEvidence(page.evidenceIDs.first) } label: { Text("Read the supporting sources →").font(.caption.weight(.semibold)).foregroundStyle(Folio.paper).frame(minHeight: 44) }.accessibilityIdentifier("preview.sources")
                        }
                    }
                    if page.media == nil || !page.body.isEmpty || !page.claims.isEmpty {
                        Text("Source context · \(ExecutionEvidence.label(for: page.evidenceMode))").font(.caption2).foregroundStyle(Folio.paper.opacity(0.75)).accessibilityIdentifier("preview.source-mode")
                    }
                }.padding(.horizontal, 3).padding(.vertical, 4)
                HStack {
                    Text("Read at your pace").font(.caption2).frame(minHeight: 44).accessibilityIdentifier("preview.reading-mode")
                    Spacer(minLength: 4)
                    Text("\(index + 1) / \(pages.count)").font(.caption2).accessibilityIdentifier("preview.position")
                    Spacer(minLength: 4)
                    Button { advance() } label: { Image(systemName: "arrow.right").frame(width: 44, height: 44) }.disabled(pages.count < 2).accessibilityLabel("Next preview segment").accessibilityIdentifier("preview.next")
                }.foregroundStyle(Folio.paper.opacity(0.9))
            }.padding(12).background(Folio.olive, in: RoundedRectangle(cornerRadius: 6))
                .onChange(of: pages.map(\.id)) { _, _ in selected = 0 }
        }
    }
    private func storyIdentity(_ beats: [ResolvedStoryBeat]) -> [String] {
        [repo.slug] + beats.flatMap { beat in
            [beat.id, beat.sceneID, beat.evidenceID, beat.narration, beat.visual.kind, beat.visual.title,
             beat.visual.cue, String(beat.visual.focus)] + beat.visual.lines
        }
    }
    private func advance() {
        guard !pages.isEmpty else { return }
        selected = (index + 1) % pages.count
    }
}

/// Scene prose and statement order come directly from the accepted source story.
/// Numbered markers show reading order, without asserting causal relationships.
private struct WalkthroughScene: View {
    let page: PreviewPage
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("SOURCE WALKTHROUGH").font(.system(size: 9, weight: .medium)).tracking(1.5).foregroundStyle(Folio.secondary)
            if page.claims.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(page.claims.enumerated()), id: \.offset) { index, _ in
                            Text("\(index + 1)").font(.caption2.monospacedDigit()).frame(width: 28, height: 28)
                                .background(Folio.surface.opacity(0.8), in: Circle()).overlay(Circle().stroke(Folio.rule))
                        }
                    }
                }.accessibilityHidden(true)
            }
            Text(page.body).font(Folio.serif(23)).fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled).accessibilityIdentifier("preview.story")
        }.padding(18).frame(maxWidth: .infinity, minHeight: 205, alignment: .leading)
            .foregroundStyle(Folio.ink).background(Folio.accentLight, in: RoundedRectangle(cornerRadius: 4))
    }
}

/// AVPlayer is created only for a supplied video URL; source pages never become fake video.
/// https://developer.apple.com/documentation/avkit/videoplayer
struct PreviewArtifact: View {
    let media: PreviewMedia
    var active = true
    @State private var player: AVPlayer?
    @State private var failed = false
    private var playbackStatus: AnyPublisher<AVPlayerItem.Status, Never> {
        player?.currentItem?.publisher(for: \.status).eraseToAnyPublisher() ?? Just(.unknown).eraseToAnyPublisher()
    }
    var body: some View {
        Group {
            if let url = media.safeURL {
                switch media.renderingKind {
                case .image:
                    AsyncImage(url: url) { phase in
                        if let image = phase.image { image.resizable().scaledToFit().accessibilityElement(children: .ignore).accessibilityLabel(media.caption ?? "Repository preview image").accessibilityIdentifier("preview.image") }
                        else if phase.error != nil { unavailable("This image could not be loaded.") }
                        else { ProgressView().tint(Folio.paper).frame(maxWidth: .infinity, maxHeight: .infinity) }
                    }
                case .video:
                    if failed { unavailable("This video could not be loaded.") }
                    else if let player { VideoPlayer(player: player) }
                    else { ProgressView().tint(Folio.paper).frame(maxWidth: .infinity, maxHeight: .infinity) }
                case .unsupported: unavailable("This preview format is not supported yet.")
                }
            } else { unavailable("No usable preview link was supplied.") }
        }.frame(maxWidth: .infinity).frame(height: 205).background(Folio.ink.opacity(0.5), in: RoundedRectangle(cornerRadius: 4)).clipped()
            .task(id: media.url) { failed = false; player = nil; if media.renderingKind == .video, let url = media.safeURL { player = AVPlayer(url: url) } }
            .onReceive(playbackStatus) { if $0 == .failed && !failed { failed = true } }
            .onChange(of: active) { _, value in if !value { player?.pause() } }
            .onDisappear { player?.pause() }
    }
    private func unavailable(_ message: String) -> some View {
        VStack(spacing: 12) { Image(systemName: "photo").font(.title2); Text(message).font(.footnote).multilineTextAlignment(.center) }.foregroundStyle(Folio.paper).padding(20).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
