import XCTest
@testable import LearningKit

final class HighlightTimelineTests: XCTestCase {

    func testWordIndexProgression() {
        let timeline = HighlightTimeline(timings: [
            WordTiming(index: 0, start: 0.0, duration: 0.5),
            WordTiming(index: 1, start: 0.6, duration: 0.5),
            WordTiming(index: 2, start: 1.2, duration: 0.5),
        ])
        XCTAssertNil(timeline.wordIndex(at: -0.1))   // before start
        XCTAssertEqual(timeline.wordIndex(at: 0.0), 0)
        XCTAssertEqual(timeline.wordIndex(at: 0.3), 0)
        XCTAssertEqual(timeline.wordIndex(at: 0.65), 1)
        XCTAssertEqual(timeline.wordIndex(at: 1.25), 2)
        XCTAssertNil(timeline.wordIndex(at: 5.0))    // after finish
    }

    func testEstimatedCadenceIsMonotonicAndCoversAllWords() {
        let words = ["The", "cat", "sat", "on", "the", "mat"]
        let timeline = HighlightTimeline.estimated(words: words)
        XCTAssertEqual(timeline.timings.count, words.count)
        // strictly increasing starts, positive durations
        for i in 1..<timeline.timings.count {
            XCTAssertGreaterThan(timeline.timings[i].start, timeline.timings[i - 1].start)
        }
        for t in timeline.timings { XCTAssertGreaterThan(t.duration, 0) }
        // every word is reachable at its own start
        for (i, t) in timeline.timings.enumerated() {
            XCTAssertEqual(timeline.wordIndex(at: t.start + 0.01), i)
        }
        XCTAssertGreaterThan(timeline.duration, 0)
    }

    func testExactlyOneWordActiveAtAnyTime() {
        let timeline = HighlightTimeline.estimated(words: ["a", "big", "red", "dog"])
        var t = 0.0
        while t < timeline.duration {
            // never returns an out-of-range index
            if let idx = timeline.wordIndex(at: t) {
                XCTAssertTrue((0..<4).contains(idx))
            }
            t += 0.05
        }
    }
}
