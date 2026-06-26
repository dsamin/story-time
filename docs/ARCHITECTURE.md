# Architecture & Brainstorm — Story Time, Your Turn

This is the locked design that the implementation follows. The README is the
canonical product spec; this doc records the engineering decisions that make it
buildable, testable, and import-clean.

## Environment note (why the code is split the way it is)

The reference build/run target is **macOS + Xcode + an iPad simulator**. CI and a
developer on a Mac run `xcodebuild` against an iPad-Pro simulator and drive the
loop with XCUITest. See `.github/workflows/ci.yml` and `docs/RUNNING.md`.

To keep the project honestly *verifiable* even off a Mac, all the product logic
that does **not** need SwiftUI / AVFoundation / SwiftData lives in plain Swift
Package targets that build and unit-test on Linux too:

- `LearningKit` — the shared chassis (ContentLibrary, AudioEngine, ReviewService).
- `StoryTimeCore` — the Story data model, `StoryValidator`, and the errorless
  `StorySession` state machine, plus the authored stories as bundle resources.

The SwiftUI app (`App/StoryTime`) consumes those packages and is compiled by the
Xcode project. Apple-only code (AVAudioPlayer / AVSpeechSynthesizer narrators,
SwiftData stores) sits behind `#if canImport(...)` so the package still compiles
on Linux, where its logic is exercised by XCTest.

## The Story data model (authoring contract)

A story is **pure data** — text plus references into the ContentLibrary. Adding a
story = writing one JSON file; `StoryValidator` confirms decodability + asset
resolution. Shapes (see `Sources/StoryTimeCore/Model/Story.swift`):

```
Story   { id, title(adult-only), cast[pictureRef], lines[Line], beats[Beat], questionSets[Question] }
Line    { words[Word], beat:beatID }
Word    { text, glue:Bool }                    // glue = spoken, not expected to be decoded
Beat    { id, image:pictureRef, caption }       // 2–3, in canonical order
Question{ prompt(SPOKEN), type:who|what|where, choices[pictureRef], answer:pictureRef, expansion(SPOKEN) }
```

- **Glue vs decodable.** Every non-`glue` word must be in the ContentLibrary's
  decodable inventory. Glue words are a tiny whitelist (`the, a, is, on, in, and,
  to, was, his`) — spoken, never expected to be sounded out.
- **Question turns & reread.** `questionSets` is a flat list of questions. A read
  through asks the first half; the **reread** asks the second half — a genuinely
  *new* question set, which is how young children consolidate a story. Floor: ≥2
  questions so the reread is always fresh.

`StoryValidator` rejects a story unless: every non-glue word resolves to the
decodable inventory; every `cast`/`image`/`choice`/`answer` ref resolves to a
real picture asset; each `answer` is one of its `choices`; choices count 2–4;
each line's `beat` names a real beat; beat ids are unique; there are **≥2
questions** and **2–3 beats**.

## The errorless state machine (no fail state is reachable)

`StorySession` (`Sources/StoryTimeCore/Session/StorySession.swift`) is a plain
class with an explicit phase enum. **There is no `.failed` case and no transition
that ends the session because of a wrong answer** — errorlessness is enforced by
construction, not by convention.

```
Phase:
  listening(reread:Int)          // story plays, word highlight, tap-a-word
  asking(turn:Int, q:Int, feedback)   // one question; feedback = .awaiting | .confirmed | .remodel
  sequencing(order:[beatID])     // any permutation of the beats
  replay(order:[beatID])         // assembled from the child's ordering
  end
```

Transitions:
- `tapChoice(ref)` while `asking`:
  - ref == answer → `feedback = .confirmed` (speak confirmation **+ expansion**) →
    on continue, advance to next question; after the last question of turn 0 →
    `listening(reread:1)`; after the last question of turn 1 → `sequencing`.
  - ref != answer → `feedback = .remodel(correct: answer)` (re-speak the prompt,
    softly highlight the correct picture) → **return to `.awaiting` on the same
    question**. No buzzer, no counter, no advance, no end.
- `confirmOrder([beatID])` while `sequencing` → **always accepted for any
  permutation** → `replay(order)` → `end`.

Invariants under test (`Tests/StoryTimeCoreTests`):
- Hammering wrong choices any number of times never leaves the question except via
  the correct answer and never reaches `.end` early.
- Every permutation of beats is accepted and reaches `replay` then `end`.
- The reread (turn 1) presents a question set disjoint from turn 0.

## LearningKit boundary (extraction-ready, no app imports)

Each engine is written with **no app-specific imports** so it lifts cleanly into a
shared `LearningKit` package reused across the 5-app slate.

- **ContentLibrary** — tagged picture/word/sound assets + the decodable inventory
  and glue whitelist. The fixed reusable cast (`cat, dog, pig, boy`) and the
  answer-choice props live in `ContentLibrary.standard`. Pure data; Linux-testable.
- **AudioEngine** — a `Narrator` protocol + a pure `HighlightTimeline` that maps
  elapsed time → currently-spoken word index (real per-word timings for recorded
  clips; an estimated cadence for the synth placeholder). `SynthNarrator`
  (`AVSpeechSynthesizer`) and `ClipNarrator` (`AVAudioPlayer`) are Apple-only and
  guarded; `MockNarrator` drives tests. The synth placeholder means the whole loop
  runs before a single clip is recorded.
- **ReviewService** (`MasteryService`) — a small cross-app spaced-repetition
  service: report a vocabulary/comprehension target as met/missed, ask what's due,
  ask which stories are due for another pass. Pure logic; Codable for on-device
  persistence; Linux-testable.

**Rule:** LearningKit never imports StoryTimeCore or the app. StoryTimeCore
depends on LearningKit. The app depends on both.

## Privacy/safety, by construction

No networking code exists in any target. No analytics, accounts, ads, or IAP.
Persistence is SwiftData on-device (app target only, Apple-guarded). The parent
gate is a press-and-hold-**then-drag** cognitive gate — not a one-tap dialog.
