import Foundation
import LearningKit

/// The errorless core loop, as a framework-free state machine. The whole app's "no way
/// to fail" guarantee is enforced *by construction* here: there is no `.failed` phase
/// and no transition that ends the session because of a wrong answer. A wrong tap only
/// re-models the answer and returns to the same question; sequencing accepts any order.
///
/// The session speaks through a `Narrator` (the synth placeholder or recorded clips) and
/// optionally reports outcomes to a `MasteryService`. It is UI-agnostic: SwiftUI wraps it
/// in an `@Observable` view model, tests drive it directly.
public final class StorySession {

    /// Feedback shown on a question. Note what is *absent*: there is no "wrong"/"fail".
    public enum Feedback: Equatable, Sendable {
        case awaiting
        case confirmed                  // correct → confirm + expansion
        case remodel(correct: String)   // wrong → gently re-model the answer, then retry
    }

    public enum Phase: Equatable, Sendable {
        case listening(reread: Int)
        case asking(turn: Int, questionIndex: Int, feedback: Feedback)
        case sequencing(order: [String])     // current working arrangement of beat ids
        case replay(order: [String])         // assembled from the child's ordering
        case end
    }

    public let story: Story
    private let narrator: Narrator
    private let mastery: MasteryService?

    public private(set) var phase: Phase {
        didSet { if phase != oldValue { onChange?() } }
    }

    /// Fires after every phase change so a view model can refresh.
    public var onChange: (() -> Void)?

    /// Fires when a *spoken prompt / expansion / re-model* finishes (not story lines or
    /// replay captions, which carry their own completions). The app uses this to advance
    /// after a confirmation is heard, or to return to "awaiting" after a re-model. In
    /// tests this is nil, so the deterministic explicit transitions are used instead.
    public var onSpeechFinished: (() -> Void)?

    /// Speak an utterance that should notify `onSpeechFinished` when done.
    private func say(_ utterance: Utterance) {
        narrator.speak(utterance, onWord: nil, onFinish: { [weak self] in self?.onSpeechFinished?() })
    }

    public init(story: Story, narrator: Narrator, mastery: MasteryService? = nil) {
        self.story = story
        self.narrator = narrator
        self.mastery = mastery
        self.phase = .listening(reread: 0)
    }

    // MARK: Derived state

    public var currentReread: Int {
        if case let .listening(r) = phase { return r }
        if case let .asking(t, _, _) = phase { return t }
        return 0
    }

    public var currentQuestion: Question? {
        guard case let .asking(turn, qi, _) = phase else { return nil }
        let qs = story.questions(forTurn: turn)
        return qi < qs.count ? qs[qi] : nil
    }

    public var isFinished: Bool { phase == .end }

    // MARK: Listening

    /// Narrate the story's lines in order, reporting the active word index per line via
    /// `onWord(lineIndex, wordIndex)` for highlighting. Calls `onFinish` when done.
    public func playStory(onWord: ((Int, Int) -> Void)? = nil, onFinish: (() -> Void)? = nil) {
        narrateLine(0, onWord: onWord, onFinish: onFinish)
    }

    private func narrateLine(_ i: Int, onWord: ((Int, Int) -> Void)?, onFinish: (() -> Void)?) {
        guard i < story.lines.count else { onFinish?(); return }
        let line = story.lines[i]
        let utterance = Utterance(text: line.text, words: line.words.map(\.text), clipName: "line_\(story.id)_\(i)")
        narrator.speak(utterance, onWord: { onWord?(i, $0) }, onFinish: { [weak self] in
            self?.narrateLine(i + 1, onWord: onWord, onFinish: onFinish)
        })
    }

    /// Re-speak a single word in isolation (tap-a-word). Never changes phase.
    public func speakWord(lineIndex: Int, wordIndex: Int) {
        guard lineIndex < story.lines.count,
              wordIndex < story.lines[lineIndex].words.count else { return }
        let w = story.lines[lineIndex].words[wordIndex].text
        narrator.speak(.phrase(w))
    }

    /// Move from listening into the question turn for the current reread.
    public func beginQuestions() {
        guard case let .listening(reread) = phase else { return }
        guard !story.questions(forTurn: reread).isEmpty else { beginSequencing(); return }
        phase = .asking(turn: reread, questionIndex: 0, feedback: .awaiting)
        narrateCurrentPrompt()
    }

    private func narrateCurrentPrompt() {
        guard let q = currentQuestion else { return }
        say(.phrase(q.prompt))
    }

    /// Re-speak the current question's prompt (a "say it again" affordance).
    public func repeatPrompt() { narrateCurrentPrompt() }

    // MARK: Answering (errorless)

    /// The child tapped a picture choice. Correct → confirm + expand. Wrong → re-model
    /// and stay on the same question. Never a buzzer, never a fail, never an advance on
    /// a wrong tap.
    public func tapChoice(_ ref: String) {
        guard case let .asking(turn, qi, _) = phase, let q = currentQuestion else { return }

        let target = MasteryService.Target(kind: .comprehension, id: "\(story.id):\(q.type.rawValue)")
        let vocab = MasteryService.Target(kind: .vocabulary, id: q.answer)

        if ref == q.answer {
            mastery?.report(target, met: true)
            mastery?.report(vocab, met: true)
            phase = .asking(turn: turn, questionIndex: qi, feedback: .confirmed)
            say(.phrase(q.expansion))
        } else {
            mastery?.report(target, met: false)
            // Re-model: re-speak the prompt and the modeled answer; highlight the right
            // picture. The child then simply tries again — no penalty, no counter.
            phase = .asking(turn: turn, questionIndex: qi, feedback: .remodel(correct: q.answer))
            say(.phrase("\(q.prompt) \(q.expansion)"))
        }
    }

    /// Called after the confirmation has been heard: advance to the next question, the
    /// reread, or the sequencing game.
    public func advanceAfterConfirm() {
        guard case let .asking(turn, qi, feedback) = phase, feedback == .confirmed else { return }
        let qs = story.questions(forTurn: turn)
        if qi + 1 < qs.count {
            phase = .asking(turn: turn, questionIndex: qi + 1, feedback: .awaiting)
            narrateCurrentPrompt()
        } else if turn == 0 {
            phase = .listening(reread: 1)   // reread the story, then a fresh question set
        } else {
            beginSequencing()
        }
    }

    /// Called after a re-model has been heard: return the same question to "awaiting" so
    /// the child can try again.
    public func readyForRetry() {
        guard case let .asking(turn, qi, feedback) = phase, case .remodel = feedback else { return }
        phase = .asking(turn: turn, questionIndex: qi, feedback: .awaiting)
    }

    // MARK: Sequencing (any order is accepted)

    public func beginSequencing(shuffled: Bool = true, using generator: inout some RandomNumberGenerator) {
        var order = story.beats.map(\.id)
        if shuffled { order.shuffle(using: &generator) }
        phase = .sequencing(order: order)
    }

    public func beginSequencing(shuffled: Bool = true) {
        var rng = SystemRandomNumberGenerator()
        beginSequencing(shuffled: shuffled, using: &rng)
    }

    /// Update the working arrangement as the child drags cards. Always allowed.
    public func setOrder(_ order: [String]) {
        guard case .sequencing = phase else { return }
        phase = .sequencing(order: order)
    }

    public var workingOrder: [String]? {
        if case let .sequencing(order) = phase { return order }
        return nil
    }

    /// The child finished arranging. *Any* permutation is accepted — there is no wrong
    /// order — and the story replays assembled from their ordering.
    public func confirmOrder() {
        guard case let .sequencing(order) = phase else { return }
        // Report comprehension of sequencing (matching canonical order is a "met"); a
        // mismatch is still never a fail — it only nudges the review service.
        if mastery != nil {
            let met = order == story.canonicalBeatOrder
            mastery?.report(.init(kind: .comprehension, id: "\(story.id):sequence"), met: met)
        }
        phase = .replay(order: order)
    }

    /// Narrate the replay in the child's chosen order, reporting each beat for animation.
    public func playReplay(onBeat: ((Int, Beat) -> Void)? = nil, onFinish: (() -> Void)? = nil) {
        guard case let .replay(order) = phase else { return }
        let beatsByID = Dictionary(uniqueKeysWithValues: story.beats.map { ($0.id, $0) })
        let ordered = order.compactMap { beatsByID[$0] }
        narrateBeat(0, ordered: ordered, onBeat: onBeat, onFinish: onFinish)
    }

    private func narrateBeat(_ i: Int, ordered: [Beat], onBeat: ((Int, Beat) -> Void)?, onFinish: (() -> Void)?) {
        guard i < ordered.count else { onFinish?(); return }
        onBeat?(i, ordered[i])
        narrator.speak(.phrase(ordered[i].caption), onWord: nil, onFinish: { [weak self] in
            self?.narrateBeat(i + 1, ordered: ordered, onBeat: onBeat, onFinish: onFinish)
        })
    }

    /// Settle on the calm end card.
    public func finishReplay() {
        guard case .replay = phase else { return }
        phase = .end
    }

    /// Stop any narration (e.g. when the child taps away).
    public func stopSpeaking() { narrator.stop() }
}
