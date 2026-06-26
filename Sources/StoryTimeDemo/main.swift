import Foundation
import LearningKit
import StoryTimeCore

// A headless driver that walks the FULL errorless core loop and prints a transcript:
// listen (with word highlighting) → tap a word → answer questions (deliberately tapping a
// WRONG picture first to show the re-model + retry, then the correct one) → reread with a
// fresh question set → order the beats → replay → calm end. This is the loop the SwiftUI
// app renders; here it runs anywhere (including this Linux CI) to prove it works.

/// Narrator that prints what the warm voice would say, and completes immediately.
final class PrintNarrator: Narrator {
    func speak(_ utterance: Utterance, onWord: ((Int) -> Void)?, onFinish: (() -> Void)?) {
        print("   🔊 \"\(utterance.text)\"")
        for i in utterance.words.indices { onWord?(i) }
        onFinish?()
    }
    func stop() {}
}

func rule(_ s: String) { print("\n\u{001B}[1m== \(s) ==\u{001B}[0m") }

let validator = StoryValidator()
let stories = try StoryLibrary.loadAll()
print("Loaded \(stories.count) authored stories; all valid: \(stories.allSatisfy { validator.isValid($0) })")

let story = stories[0]
let narrator = PrintNarrator()
let mastery = MasteryService()
let session = StorySession(story: story, narrator: narrator, mastery: mastery)

rule("1. LISTEN  (story: \(story.title))")
session.playStory(onWord: { line, word in
    let w = story.lines[line].words[word]
    print("   …highlight L\(line) W\(word): '\(w.text)'\(w.glue ? " (glue)" : "")")
})

rule("tap-a-word: replay one word")
session.speakWord(lineIndex: 0, wordIndex: 1)

func answerTurn(_ turn: Int) {
    session.beginQuestions()
    while case let .asking(_, _, feedback) = session.phase, feedback == .awaiting, let q = session.currentQuestion {
        print("\n   ❓ (spoken) \(q.prompt)   choices: \(q.choices)")
        // Deliberately tap a WRONG picture first.
        if let wrong = q.choices.first(where: { $0 != q.answer }) {
            print("   👆 taps WRONG picture: \(wrong)")
            session.tapChoice(wrong)
            if case let .asking(_, _, .remodel(correct)) = session.phase {
                print("   ✓ errorless: no buzzer, re-models correct answer → \(correct); child may retry")
            } else {
                fatalError("expected re-model on a wrong tap")
            }
            session.readyForRetry()
        }
        // Now tap the correct picture.
        print("   👆 taps CORRECT picture: \(q.answer)")
        session.tapChoice(q.answer)
        guard case .asking(_, _, .confirmed) = session.phase else { fatalError("expected confirmed") }
        print("   ✓ confirmed + expanded")
        session.advanceAfterConfirm()
    }
}

rule("2. YOUR TURN  (question set A)")
answerTurn(0)

rule("3. REREAD  → fresh question set B")
if case .listening(let r) = session.phase {
    print("   (reread #\(r))")
    session.playStory()
    answerTurn(1)
}

rule("4. SEQUENCING  (drag beats into order — any order accepted)")
guard case let .sequencing(shuffled) = session.phase else { fatalError("expected sequencing") }
print("   shuffled cards: \(shuffled)")
let chosen = Array(shuffled.reversed())          // child arranges them (any order)
print("   child orders them: \(chosen)")
session.setOrder(chosen)
session.confirmOrder()

rule("5. REPLAY  (assembled from the child's ordering)")
session.playReplay(onBeat: { i, beat in print("   ▶︎ beat \(i + 1): \(beat.image)") })
session.finishReplay()

rule("6. END  (calm — no score, no nag)")
print("   phase = \(session.phase)")
precondition(session.phase == .end, "loop must reach the calm end")

print("\n\u{001B}[1;32m✅ Full core loop completed end-to-end with no reachable fail state.\u{001B}[0m")
print("   mastery records gathered: \(mastery.snapshot().count)")
