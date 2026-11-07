import SwiftUI
import GitTokCore

struct StoryboardPlayer: View {
    let onEvidence: (String?) -> Void
    var active: Bool
    @State private var playback: StoryboardPlayback
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(beats: [ResolvedStoryBeat], active: Bool, onEvidence: @escaping (String?) -> Void) {
        self.active = active; self.onEvidence = onEvidence
        _playback = State(initialValue: StoryboardPlayback(beats: beats))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            sceneNavigation
            HStack(alignment: .firstTextBaseline) {
                Text(playback.beat.sceneTitle).font(.caption.weight(.semibold)).accessibilityIdentifier("preview.title")
                Spacer(minLength: 4)
                Text("SOURCE WALKTHROUGH").font(.system(size: 8, weight: .medium)).tracking(1)
            }.foregroundStyle(Folio.paper.opacity(0.9))
            StoryboardVisual(visual: playback.beat.visual, revealed: playback.revealed, progress: playback.visualProgress, playing: playback.isPlaying)
            StoryboardCaption(narration: playback.beat.narration, wordRange: playback.wordRange)
            if playback.state == .unavailable {
                Label("No native voice is available. Read the captions and use the arrows.", systemImage: "speaker.slash")
                    .font(.caption2).foregroundStyle(Folio.paper).accessibilityIdentifier("storyboard.unavailable")
            }
            HStack {
                Button { playback.pause(); onEvidence(playback.beat.evidenceID) } label: {
                    Label("Read supporting source", systemImage: "text.magnifyingglass").font(.caption.weight(.semibold)).frame(minHeight: 44)
                }.accessibilityIdentifier("preview.sources")
                Spacer(minLength: 4)
                Text("Source only · Not executed").font(.system(size: 9)).accessibilityIdentifier("preview.source-mode")
            }.foregroundStyle(Folio.paper.opacity(0.9))
            controls
            #if DEBUG
            if playback.usesManualDriver { testControls }
            if playback.usesUnavailableTestDriver { Text("Unavailable narration test driver · no speech audio").font(.caption2).foregroundStyle(Folio.paper) }
            #endif
        }.padding(12).background(Folio.olive, in: RoundedRectangle(cornerRadius: 6))
            .onChange(of: active) { _, value in if !value { playback.pause() } }
            .onChange(of: scenePhase) { _, value in if value != .active { playback.pause() } }
            .onDisappear { playback.stop() }
    }
    private var sceneNavigation: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(playback.beats.enumerated()), id: \.element.id) { index, beat in
                        Button { playback.select(index) } label: {
                            Capsule().fill(index <= playback.index ? Folio.accentLight : Folio.paper.opacity(0.25))
                                .frame(width: max(22, min(70, 280 / CGFloat(playback.beats.count))), height: 3).frame(minWidth: 44, minHeight: 44)
                        }.id(beat.id).accessibilityLabel("Walkthrough beat \(index + 1) of \(playback.beats.count): \(beat.sceneTitle)")
                            .accessibilityAddTraits(index == playback.index ? .isSelected : [])
                    }
                }
            }.onChange(of: playback.index) { _, _ in
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { proxy.scrollTo(playback.beat.id, anchor: .center) }
            }
        }
    }
    private var controls: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Button { playback.previous() } label: { Image(systemName: "backward.end.fill").frame(width: 44, height: 44) }
                    .disabled(playback.index == 0).accessibilityLabel("Previous walkthrough beat").accessibilityIdentifier("preview.previous")
                Spacer(minLength: 0)
                Button { playback.toggle() } label: {
                    Label(playback.buttonTitle, systemImage: playback.isPlaying ? "pause.fill" : "play.fill")
                        .font(.caption.weight(.semibold)).padding(.horizontal, 12).frame(minHeight: 44)
                        .overlay(Capsule().stroke(Folio.paper.opacity(0.3)))
                }.disabled(!active || playback.state == .unavailable).accessibilityIdentifier("preview.play")
                Spacer(minLength: 0)
                Button { playback.next() } label: { Image(systemName: "forward.end.fill").frame(width: 44, height: 44) }
                    .disabled(playback.index == playback.beats.count - 1).accessibilityLabel("Next walkthrough beat").accessibilityIdentifier("preview.next")
            }
            HStack {
                Button { playback.replay() } label: { Label("Replay beat", systemImage: "arrow.counterclockwise").font(.caption2).frame(minHeight: 44) }
                    .disabled(!active || playback.state == .unavailable).accessibilityIdentifier("preview.replay")
                Spacer()
                Text("\(playback.index + 1) / \(playback.beats.count)").font(.caption2.monospacedDigit()).accessibilityIdentifier("preview.position")
            }
        }.foregroundStyle(Folio.paper)
    }
    #if DEBUG
    private var testControls: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Manual narration test driver · no speech audio").font(.caption2)
            HStack {
                Button("Test: next spoken word") { playback.testNextWord() }.accessibilityIdentifier("storyboard.test.word")
                Spacer()
                Button("Test: finish narration") { playback.testFinish() }.accessibilityIdentifier("storyboard.test.finish")
            }.font(.caption2).frame(minHeight: 44)
            Button("Test: stale completion") { playback.testStaleCompletion() }.font(.caption2).frame(minHeight: 44).accessibilityIdentifier("storyboard.test.stale")
        }.foregroundStyle(Folio.paper).padding(8).overlay(RoundedRectangle(cornerRadius: 4).stroke(Folio.paper.opacity(0.4)))
    }
    #endif
}
