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
        s.onChange = { [weak self] in self?.phase = self?.session.phase ?? .end }
        s.onSpeechFinished = { [weak self] in self?.handleSpeechFinished() }
    }

    var story: Story { session.story }
    var currentQuestion: Question? { session.currentQuestion }

    // MARK: Listening

    func startListening() {
        guard !isNarrating else { return }
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
