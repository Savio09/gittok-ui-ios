import AVFoundation
import Foundation

/// The token fences delayed callbacks after a scene, repository, or utterance changes.
enum NarrationEvent {
    case word(UUID, NSRange), finished(UUID), unavailable(UUID)
}

@MainActor protocol NarrationDriver: AnyObject {
    var onEvent: ((NarrationEvent) -> Void)? { get set }
    var available: Bool { get }
    func speak(_ text: String, token: UUID)
    func pause()
    func resume() -> Bool
    func stop()
}

/// Retention prevents a retired utterance's object address being reused while its
/// callback is queued. Only object identity is inspected, on the main actor.
private final class RetainedUtterance: @unchecked Sendable {
    let value: AVSpeechUtterance
    init(_ value: AVSpeechUtterance) { self.value = value }
}

@MainActor final class NativeNarrationDriver: NSObject, NarrationDriver, AVSpeechSynthesizerDelegate {
    var onEvent: ((NarrationEvent) -> Void)?
    private let synthesizer = AVSpeechSynthesizer()
    private var current: (ObjectIdentifier, UUID)?
    var available: Bool { !AVSpeechSynthesisVoice.speechVoices().isEmpty }

    override init() { super.init(); synthesizer.delegate = self }
    func speak(_ text: String, token: UUID) {
        stop()
        guard let voice = AVSpeechSynthesisVoice(language: "en-US") ?? AVSpeechSynthesisVoice.speechVoices().first else {
            onEvent?(.unavailable(token)); return
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        current = (ObjectIdentifier(utterance), token)
        synthesizer.speak(utterance)
    }
    func pause() { synthesizer.pauseSpeaking(at: .immediate) }
    func resume() -> Bool { synthesizer.continueSpeaking() }
    func stop() { current = nil; synthesizer.stopSpeaking(at: .immediate) }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        let retained = RetainedUtterance(utterance)
        Task { @MainActor [weak self] in
            guard let self, let (active, token) = current, active == ObjectIdentifier(retained.value) else { return }
            onEvent?(.word(token, characterRange))
        }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let retained = RetainedUtterance(utterance)
        Task { @MainActor [weak self] in
            guard let self, let (active, token) = current, active == ObjectIdentifier(retained.value) else { return }
            current = nil; onEvent?(.finished(token))
        }
    }
}

#if DEBUG
@MainActor final class UnavailableNarrationDriver: NarrationDriver {
    var onEvent: ((NarrationEvent) -> Void)?
    let available = false
    func speak(_ text: String, token: UUID) { onEvent?(.unavailable(token)) }
    func pause() {}
    func resume() -> Bool { false }
    func stop() {}
}

/// Only explicit UI tests use this driver. It makes no audio or timing claims.
@MainActor final class ManualNarrationDriver: NarrationDriver {
    var onEvent: ((NarrationEvent) -> Void)?
    let available = true
    private var token: UUID?
    private var ranges: [NSRange] = []
    private var cursor = 0
    private var paused = false
    private var staleToken: UUID?
    func speak(_ text: String, token: UUID) {
        self.token = token; cursor = 0; paused = false; ranges = []
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .byWords) { _, range, _, _ in
            self.ranges.append(NSRange(range, in: text))
        }
    }
    func pause() { paused = true }
    func resume() -> Bool { paused = false; return token != nil }
    func stop() { staleToken = token ?? staleToken; token = nil; ranges = []; cursor = 0 }
    func nextWord() {
        guard !paused, let token, cursor < ranges.count else { return }
        onEvent?(.word(token, ranges[cursor])); cursor += 1
    }
    func emitStaleCompletion() { if let staleToken { onEvent?(.finished(staleToken)) } }
    func finish() {
        guard !paused, let token else { return }
        self.token = nil; staleToken = token; onEvent?(.finished(token))
    }
}
#endif
