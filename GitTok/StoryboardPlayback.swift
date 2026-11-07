import Foundation
import Observation
import GitTokCore

@MainActor @Observable final class StoryboardPlayback {
    enum State { case ready, playing, paused, finished, unavailable }
    let beats: [ResolvedStoryBeat]
    private(set) var index = 0
    private(set) var state: State = .ready
    private(set) var wordRange: NSRange?
    private(set) var revealed = false
    @ObservationIgnored private let driver: any NarrationDriver
    @ObservationIgnored private var token: UUID?
    var beat: ResolvedStoryBeat { beats[index] }
    var isPlaying: Bool { state == .playing }
    var buttonTitle: String {
        switch state {
        case .playing: "Pause narration"
        case .paused: "Resume narration"
        case .finished: "Replay narration"
        case .unavailable: "Narration unavailable"
        case .ready: "Play narration"
        }
    }
    var visualProgress: Double {
        guard revealed, let wordRange else { return 0 }
        let cue = beat.cueUTF16Offset
        return min(1, Double(max(1, NSMaxRange(wordRange) - cue)) / Double(max(1, beat.narration.utf16.count - cue)))
    }
    init(beats: [ResolvedStoryBeat], driver: (any NarrationDriver)? = nil) {
        precondition(!beats.isEmpty)
        self.beats = beats
        #if DEBUG
        if let driver { self.driver = driver }
        else if ProcessInfo.processInfo.environment["GITTOK_NARRATION_DRIVER"] == "unavailable" { self.driver = UnavailableNarrationDriver() }
        else if ProcessInfo.processInfo.environment["GITTOK_NARRATION_DRIVER"] == "manual" { self.driver = ManualNarrationDriver() }
        else { self.driver = NativeNarrationDriver() }
        #else
        self.driver = driver ?? NativeNarrationDriver()
        #endif
        self.driver.onEvent = { [weak self] in self?.receive($0) }
        if !self.driver.available { state = .unavailable }
    }
    func toggle() {
        if isPlaying { pause(); return }
        guard driver.available else { state = .unavailable; return }
        if state == .paused, token != nil, driver.resume() { state = .playing }
        else { start() }
    }
    func pause() {
        guard isPlaying else { return }
        state = .paused; driver.pause()
    }
    func stop() {
        token = nil; driver.stop()
        if state != .unavailable { state = .ready }
        wordRange = nil
    }
    func select(_ position: Int) {
        guard beats.indices.contains(position) else { return }
        stop(); index = position; revealed = false
    }
    func next() { select(index + 1) }
    func previous() { select(index - 1) }
    func replay() { stop(); revealed = false; start() }
    private func start() {
        let newToken = UUID(); token = newToken; wordRange = nil; revealed = false; state = .playing
        driver.speak(beat.narration, token: newToken)
    }
    private func receive(_ event: NarrationEvent) {
        switch event {
        case let .word(eventToken, range):
            guard token == eventToken, isPlaying else { return }
            wordRange = range
            if beat.shouldRevealVisual(for: range) { revealed = true }
        case let .finished(eventToken):
            guard token == eventToken, isPlaying else { return }
            token = nil; wordRange = nil; revealed = true
            if index + 1 < beats.count { index += 1; start() }
            else { state = .finished }
        case let .unavailable(eventToken):
            guard token == eventToken else { return }
            token = nil; state = .unavailable; wordRange = nil
        }
    }
    #if DEBUG
    var usesUnavailableTestDriver: Bool { driver is UnavailableNarrationDriver }
    var usesManualDriver: Bool { driver is ManualNarrationDriver }
    func testNextWord() { (driver as? ManualNarrationDriver)?.nextWord() }
    func testStaleCompletion() { (driver as? ManualNarrationDriver)?.emitStaleCompletion() }
    func testFinish() { (driver as? ManualNarrationDriver)?.finish() }
    #endif
}
