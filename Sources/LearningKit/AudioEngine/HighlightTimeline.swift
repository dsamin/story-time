import Foundation

/// Per-word timing for word-by-word highlighting.
public struct WordTiming: Codable, Sendable, Equatable {
    public let index: Int
    public let start: TimeInterval
    public let duration: TimeInterval

    public init(index: Int, start: TimeInterval, duration: TimeInterval) {
        self.index = index
        self.start = start
        self.duration = duration
    }

    public var end: TimeInterval { start + duration }
}

/// A pure, framework-free model that maps elapsed playback time to the index of the
/// word currently being spoken. Real per-word timings come from recorded-clip
/// metadata; the synthesizer placeholder uses an estimated cadence. Either way the
/// view just asks the timeline "which word now?", so highlighting is identical and
/// fully testable without any audio framework.
public struct HighlightTimeline: Sendable, Equatable {
    public let timings: [WordTiming]

    public init(timings: [WordTiming]) {
        self.timings = timings.sorted { $0.start < $1.start }
    }

    /// Total spoken duration of the line.
    public var duration: TimeInterval { timings.map(\.end).max() ?? 0 }

    /// The index of the word being spoken at `t` seconds, or nil before the first /
    /// after the last word.
    public func wordIndex(at t: TimeInterval) -> Int? {
        guard !timings.isEmpty else { return nil }
        if t < timings[0].start { return nil }
        // Walk to the last word whose window has started; clamp inside its window.
        var current: Int? = nil
        for timing in timings {
            if t >= timing.start { current = timing.index } else { break }
        }
        if let c = current, let last = timings.last, t > last.end, c == last.index {
            return nil // finished
        }
        return current
    }

    /// Estimate a cadence for the synthesizer placeholder: each word's spoken length
    /// is proportional to its character count, scaled to a calm reading pace. This is
    /// what lets the full loop run before a single human clip is recorded.
    public static func estimated(
        words: [String],
        wordsPerMinute: Double = 120,
        gap: TimeInterval = 0.08
    ) -> HighlightTimeline {
        let perChar = (60.0 / wordsPerMinute) / 5.0 // ~5 chars per "average" word
        var t: TimeInterval = 0
        var out: [WordTiming] = []
        for (i, w) in words.enumerated() {
            let len = max(1, ContentLibrary.normalize(w).count)
            let dur = max(0.22, Double(len) * perChar)
            out.append(WordTiming(index: i, start: t, duration: dur))
            t += dur + gap
        }
        return HighlightTimeline(timings: out)
    }
}
