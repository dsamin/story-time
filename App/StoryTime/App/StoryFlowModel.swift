import SwiftUI
import LearningKit
import StoryTimeCore

/// SwiftUI-facing wrapper around the errorless `StorySession`. Mirrors the session's
/// phase into observable state and drives narration + highlight/feedback animation.
@Observable
final class StoryFlowModel {
    let session: StorySession
    let library: ContentLibrary
    let onExit: () -> Void

    /// Mirror of `session.phase` (the session itself is framework-free and not observable).
    private(set) var phase: StorySession.Phase

    // Listening / highlighting
    var activeLine: Int? = nil
    var activeWord: Int? = nil
    var isNarrating = false

    // Question feedback
    var lastTappedChoice: String? = nil

    // Replay
    var replayBeatIndex: Int? = nil

    init(story: Story, narrator: Narrator, mastery: MasteryService, library: ContentLibrary, onExit: @escaping () -> Void) {
        self.library = library
        self.onExit = onExit
        let s = StorySession(story: story, narrator: narrator, mastery: mastery)
        self.session = s
        self.phase = s.phase
        s.onChange = { [weak self] in self?.syncPhase() }
        s.onSpeechFinished = { [weak self] in self?.handleSpeechFinished() }
    }

    var story: Story { session.story }
    var currentQuestion: Question? { session.currentQuestion }

    /// Tracks which reread index we've already started narrating, so the listen→questions
    /// advance happens exactly once per listen — whether kicked by the view's `onAppear`
    /// or by observing the phase change (the latter is the reliable path for the reread).
    private var lastListenStarted: Int? = nil

    private func syncPhase() {
        phase = session.phase
        beginListeningIfNeeded()
    }

    // MARK: Listening

    /// Start (or restart) narration for the current `.listening` phase, once per reread.
    /// Driven by phase observation rather than relying solely on the view's onAppear.
    func beginListeningIfNeeded() {
        guard case let .listening(reread) = session.phase, lastListenStarted != reread else { return }
        lastListenStarted = reread
        startListening()
    }

    func startListening() {
        session.stopSpeaking()
        isNarrating = true
        activeLine = 0
        activeWord = nil
        session.playStory(
            onWord: { [weak self] line, word in
                withAnimation(Motion.wordAdvance) { self?.activeLine = line; self?.activeWord = word }
            },
            onFinish: { [weak self] in
                self?.isNarrating = false
                self?.session.beginQuestions()
            }
        )
    }

    func replayStory() {
        session.stopSpeaking()
        isNarrating = false
        startListening()
    }

    func speakWord(line: Int, word: Int) {
        withAnimation(Motion.wordAdvance) { activeLine = line; activeWord = word }
        session.speakWord(lineIndex: line, wordIndex: word)
    }

    // MARK: Answering

    func tap(choice: String) {
        guard case .asking = phase else { return }
        // Ignore taps while a confirmation/re-model is mid-speech.
        if case .asking(_, _, .awaiting) = phase {} else { return }
        lastTappedChoice = choice
        session.tapChoice(choice)
    }

    func repeatPrompt() { session.repeatPrompt() }

    private func handleSpeechFinished() {
        switch session.phase {
        case .asking(_, _, .confirmed):
            session.advanceAfterConfirm()
        case .asking(_, _, .remodel):
            session.readyForRetry()
            lastTappedChoice = nil
        default:
            break
        }
    }

    // MARK: Sequencing

    func setOrder(_ order: [String]) { session.setOrder(order) }
    func confirmOrder() { session.confirmOrder() }

    // MARK: Replay

    func startReplay() {
        replayBeatIndex = nil
        session.playReplay(
            onBeat: { [weak self] i, _ in withAnimation(Motion.replayBeat) { self?.replayBeatIndex = i } },
            onFinish: { [weak self] in self?.session.finishReplay() }
        )
    }

    func exit() {
        session.stopSpeaking()
        onExit()
    }
}
