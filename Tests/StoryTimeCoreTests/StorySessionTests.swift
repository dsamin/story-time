import XCTest
@testable import StoryTimeCore
import LearningKit

/// Deterministic generator so sequencing shuffles are reproducible in tests.
struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

final class StorySessionTests: XCTestCase {

    func loadFirstStory() throws -> Story {
        let stories = try StoryLibrary.loadAll()
        return try XCTUnwrap(stories.first)
    }

    // MARK: The full happy-path core loop, driven end to end.

    func testFullCoreLoopReachesEndWithoutFailState() throws {
        let story = try loadFirstStory()
        let narrator = MockNarrator()
        let session = StorySession(story: story, narrator: narrator)

        // 1. Listen (reread 0): the story narrates with word highlights.
        var highlighted: [(Int, Int)] = []
        var finishedListening = false
        session.playStory(onWord: { highlighted.append(($0, $1)) }, onFinish: { finishedListening = true })
        XCTAssertTrue(finishedListening)
        XCTAssertFalse(highlighted.isEmpty, "word-by-word highlighting fired")

        // tap-a-word replays a single word
        narrator.reset()
        session.speakWord(lineIndex: 0, wordIndex: 1)
        XCTAssertEqual(narrator.spoken.count, 1)

        // 2. Your turn — answer turn-0 questions by tapping the correct picture.
        session.beginQuestions()
        try answerTurnCorrectly(session, turn: 0)

        // After turn 0 the story rereads.
        XCTAssertEqual(session.phase, .listening(reread: 1))

        // 3. Reread, then a NEW question set.
        session.playStory()
        session.beginQuestions()
        XCTAssertEqual(session.currentReread, 1)
        try answerTurnCorrectly(session, turn: 1)

        // 4. Sequencing — any order is accepted.
        guard case .sequencing = session.phase else { return XCTFail("expected sequencing, got \(session.phase)") }
        let order = try XCTUnwrap(session.workingOrder)
        XCTAssertEqual(Set(order), Set(story.beats.map(\.id)))
        session.confirmOrder()

        // 5. Replay assembled from the child's ordering, then the calm end.
        var replayedBeats: [Int] = []
        var replayDone = false
        session.playReplay(onBeat: { i, _ in replayedBeats.append(i) }, onFinish: { replayDone = true })
        XCTAssertEqual(replayedBeats, Array(0..<story.beats.count))
        XCTAssertTrue(replayDone)
        session.finishReplay()

        XCTAssertEqual(session.phase, .end)
        XCTAssertTrue(session.isFinished)
    }

    private func answerTurnCorrectly(_ session: StorySession, turn: Int) throws {
        let questions = session.story.questions(forTurn: turn)
        for _ in questions {
            let q = try XCTUnwrap(session.currentQuestion)
            session.tapChoice(q.answer)
            // confirmed, not failed
            guard case .asking(_, _, .confirmed) = session.phase else {
                return XCTFail("expected confirmed feedback, got \(session.phase)")
            }
            session.advanceAfterConfirm()
        }
    }

    // MARK: Errorless — wrong taps never fail, never advance, never buzz.

    func testWrongTapsAreErrorlessAndUnlimited() throws {
        let story = try loadFirstStory()
        let narrator = MockNarrator()
        let session = StorySession(story: story, narrator: narrator)
        session.beginQuestions()

        let q = try XCTUnwrap(session.currentQuestion)
        let wrong = try XCTUnwrap(q.choices.first { $0 != q.answer })

        // Hammer the wrong answer many times.
        for _ in 0..<25 {
            let before = session.phase
            session.tapChoice(wrong)
            // Feedback is a gentle re-model pointing at the CORRECT answer — never a fail.
            guard case let .asking(_, _, .remodel(correct)) = session.phase else {
                return XCTFail("a wrong tap must re-model, got \(session.phase)")
            }
            XCTAssertEqual(correct, q.answer)
            // We never left this question and never reached the end.
            XCTAssertNotEqual(session.phase, .end)
            // Still the same question index as before the tap.
            if case let .asking(_, qiBefore, _) = before,
               case let .asking(_, qiAfter, _) = session.phase {
                XCTAssertEqual(qiBefore, qiAfter)
            }
            session.readyForRetry()
            guard case .asking(_, _, .awaiting) = session.phase else {
                return XCTFail("retry should return to awaiting")
            }
        }

        // There is no reachable fail state: a correct tap still works after 25 misses.
        session.tapChoice(q.answer)
        guard case .asking(_, _, .confirmed) = session.phase else {
            return XCTFail("correct tap after many misses should confirm")
        }
    }

    func testCorrectTapSpeaksConfirmationPlusExpansion() throws {
        let story = try loadFirstStory()
        let narrator = MockNarrator()
        let session = StorySession(story: story, narrator: narrator)
        session.beginQuestions()
        let q = try XCTUnwrap(session.currentQuestion)
        narrator.reset()
        session.tapChoice(q.answer)
        XCTAssertEqual(narrator.lastSpokenText, q.expansion, "a correct tap is confirmed AND expanded")
    }

    func testWrongTapReModelsByReSpeaking() throws {
        let story = try loadFirstStory()
        let narrator = MockNarrator()
        let session = StorySession(story: story, narrator: narrator)
        session.beginQuestions()
        let q = try XCTUnwrap(session.currentQuestion)
        let wrong = try XCTUnwrap(q.choices.first { $0 != q.answer })
        narrator.reset()
        session.tapChoice(wrong)
        // It re-speaks (re-models) the answer — and crucially says something, no buzzer.
        XCTAssertEqual(narrator.spoken.count, 1)
        XCTAssertTrue(narrator.lastSpokenText?.contains(q.expansion) ?? false)
    }

    // MARK: Sequencing accepts every permutation.

    func testEveryBeatPermutationReachesReplayThenEnd() throws {
        let story = try loadFirstStory()
        let beatIDs = story.beats.map(\.id)
        for permutation in permutations(beatIDs) {
            let session = StorySession(story: story, narrator: MockNarrator())
            var rng = SeededGenerator(seed: 1)
            session.beginSequencing(using: &rng)
            session.setOrder(permutation)
            session.confirmOrder()
            guard case let .replay(order) = session.phase else {
                return XCTFail("permutation \(permutation) should reach replay")
            }
            XCTAssertEqual(order, permutation, "replay uses the child's exact ordering")
            session.playReplay()
            session.finishReplay()
            XCTAssertEqual(session.phase, .end)
        }
    }

    // MARK: Reread presents a disjoint question set.

    func testRereadDrawsFreshQuestions() throws {
        let story = try loadFirstStory()
        let session = StorySession(story: story, narrator: MockNarrator())

        session.beginQuestions()
        let turn0 = collectPrompts(session, turn: 0)
        // advance into reread
        XCTAssertEqual(session.phase, .listening(reread: 1))
        session.beginQuestions()
        let turn1 = collectPrompts(session, turn: 1)
        XCTAssertFalse(turn0.isEmpty)
        XCTAssertFalse(turn1.isEmpty)
        XCTAssertTrue(Set(turn0).isDisjoint(with: Set(turn1)), "reread must be a new set")
    }

    private func collectPrompts(_ session: StorySession, turn: Int) -> [String] {
        var prompts: [String] = []
        let count = session.story.questions(forTurn: turn).count
        for _ in 0..<count {
            guard let q = session.currentQuestion else { break }
            prompts.append(q.prompt)
            session.tapChoice(q.answer)
            session.advanceAfterConfirm()
        }
        return prompts
    }

    // MARK: Mastery reporting flows through the session.

    func testMasteryRecordsOutcomes() throws {
        let story = try loadFirstStory()
        let mastery = MasteryService()
        let session = StorySession(story: story, narrator: MockNarrator(), mastery: mastery)
        session.beginQuestions()
        let q = try XCTUnwrap(session.currentQuestion)
        session.tapChoice(q.answer)
        let target = MasteryService.Target(kind: .comprehension, id: "\(story.id):\(q.type.rawValue)")
        XCTAssertEqual(mastery.record(for: target)?.met, 1)
    }
}

// Small permutation helper (beat counts are 2–3, so this is tiny).
func permutations<T>(_ items: [T]) -> [[T]] {
    guard items.count > 1 else { return [items] }
    var result: [[T]] = []
    for (i, item) in items.enumerated() {
        var rest = items
        rest.remove(at: i)
        for p in permutations(rest) { result.append([item] + p) }
    }
    return result
}
