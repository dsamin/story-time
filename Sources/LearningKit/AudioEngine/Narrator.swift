import Foundation

/// A unit of speech the app asks the engine to narrate.
///
/// `clipName` names a pre-recorded human-voice resource (played via `AVAudioPlayer`);
/// when it is absent the engine falls back to the `AVSpeechSynthesizer` placeholder so
/// the loop is fully testable before any voice is recorded. `words` drives word-by-word
/// highlighting via a `HighlightTimeline`.
public struct Utterance: Sendable, Equatable {
    public let text: String
    public let words: [String]
    public let clipName: String?
    public let timings: [WordTiming]?

    public init(text: String, words: [String]? = nil, clipName: String? = nil, timings: [WordTiming]? = nil) {
        self.text = text
        self.words = words ?? text.split(separator: " ").map(String.init)
        self.clipName = clipName
        self.timings = timings
    }

    /// A single spoken word/phrase with no per-word highlighting (prompts, expansions).
    public static func phrase(_ text: String, clipName: String? = nil) -> Utterance {
        Utterance(text: text, words: [text], clipName: clipName)
    }

    /// The timeline to drive highlighting: real clip timings if present, else estimated.
    public func highlightTimeline() -> HighlightTimeline {
        if let t = timings, !t.isEmpty { return HighlightTimeline(timings: t) }
        return HighlightTimeline.estimated(words: words)
    }
}

/// Drives narration and reports word boundaries for highlighting. Implementations:
/// `ClipNarrator` (recorded human voice), `SynthNarrator` (placeholder), and
/// `MockNarrator` (tests). No app-specific imports — part of the shared chassis.
public protocol Narrator: AnyObject {
    /// Speak an utterance. `onWord` fires with the current word index as speech
    /// progresses (driven by the utterance's `HighlightTimeline`); `onFinish` fires
    /// once when speech completes (or is interrupted by a new `speak`).
    func speak(_ utterance: Utterance, onWord: ((Int) -> Void)?, onFinish: (() -> Void)?)

    /// Stop any current speech immediately. Does not call `onFinish`.
    func stop()
}

public extension Narrator {
    func speak(_ utterance: Utterance) { speak(utterance, onWord: nil, onFinish: nil) }
}
