import Foundation

#if canImport(AVFoundation)
import AVFoundation

/// The placeholder voice. `AVSpeechSynthesizer` speaks the text and reports real word
/// boundaries, so the whole loop is playable before any human clip is recorded. This
/// is the swappable dev stand-in the README calls for.
public final class SynthNarrator: NSObject, Narrator, AVSpeechSynthesizerDelegate {
    private let synth = AVSpeechSynthesizer()
    private var words: [String] = []
    private var ranges: [NSRange] = []
    private var onWord: ((Int) -> Void)?
    private var onFinish: (() -> Void)?
    private var fullText: NSString = ""

    /// Calm, slightly slow rate suited to a 4-year-old.
    public var rate: Float = 0.42
    public var pitch: Float = 1.05
    public var voiceIdentifier: String?

    public override init() {
        super.init()
        synth.delegate = self
    }

    public func speak(_ utterance: Utterance, onWord: ((Int) -> Void)?, onFinish: (() -> Void)?) {
        synth.stopSpeaking(at: .immediate)
        self.words = utterance.words
        self.onWord = onWord
        self.onFinish = onFinish
        self.fullText = utterance.text as NSString
        // Precompute the character range of each word so didSpeakRange maps to an index.
        self.ranges = Self.wordRanges(in: utterance.text, words: utterance.words)

        let u = AVSpeechUtterance(string: utterance.text)
        u.rate = rate
        u.pitchMultiplier = pitch
        if let id = voiceIdentifier, let v = AVSpeechSynthesisVoice(identifier: id) {
            u.voice = v
        }
        synth.speak(u)
    }

    public func stop() {
        onFinish = nil
        synth.stopSpeaking(at: .immediate)
    }

    public func speechSynthesizer(_ s: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        guard let idx = ranges.firstIndex(where: { NSIntersectionRange($0, characterRange).length > 0 }) else { return }
        onWord?(idx)
    }

    public func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let f = onFinish
        onFinish = nil
        f?()
    }

    private static func wordRanges(in text: String, words: [String]) -> [NSRange] {
        let ns = text as NSString
        var ranges: [NSRange] = []
        var searchStart = 0
        for w in words {
            let remaining = NSRange(location: searchStart, length: ns.length - searchStart)
            let found = ns.range(of: w, options: [], range: remaining)
            if found.location != NSNotFound {
                ranges.append(found)
                searchStart = found.location + found.length
            } else {
                ranges.append(NSRange(location: searchStart, length: 0))
            }
        }
        return ranges
    }
}

/// Plays pre-recorded human-voice clips. Word-by-word highlighting is driven from the
/// utterance's per-word `HighlightTimeline` via a display-linked progress poll.
public final class ClipNarrator: NSObject, Narrator, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    private var timeline = HighlightTimeline(timings: [])
    private var onWord: ((Int) -> Void)?
    private var onFinish: (() -> Void)?
    private var lastIndex: Int? = nil
    private var displayTimer: Timer?
    private let bundle: Bundle

    /// Falls back to this when a clip is missing, so a half-recorded library still runs.
    public let fallback: Narrator

    public init(bundle: Bundle = .main, fallback: Narrator) {
        self.bundle = bundle
        self.fallback = fallback
        super.init()
    }

    public func speak(_ utterance: Utterance, onWord: ((Int) -> Void)?, onFinish: (() -> Void)?) {
        stop()
        guard let clip = utterance.clipName,
              let url = bundle.url(forResource: clip, withExtension: "m4a") ?? bundle.url(forResource: clip, withExtension: "caf"),
              let p = try? AVAudioPlayer(contentsOf: url) else {
            // No recorded clip yet — use the placeholder voice.
            fallback.speak(utterance, onWord: onWord, onFinish: onFinish)
            return
        }
        self.timeline = utterance.highlightTimeline()
        self.onWord = onWord
        self.onFinish = onFinish
        self.lastIndex = nil
        p.delegate = self
        self.player = p
        p.play()
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common)
        self.displayTimer = timer
    }

    private func tick() {
        guard let p = player else { return }
        if let idx = timeline.wordIndex(at: p.currentTime), idx != lastIndex {
            lastIndex = idx
            onWord?(idx)
        }
    }

    public func stop() {
        displayTimer?.invalidate(); displayTimer = nil
        onFinish = nil
        player?.stop(); player = nil
    }

    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        displayTimer?.invalidate(); displayTimer = nil
        let f = onFinish
        onFinish = nil
        self.player = nil
        f?()
    }
}
#endif
