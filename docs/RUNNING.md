# Building, running, and verifying

There are two layers, verified two ways.

## 1. The core loop logic — runs anywhere (incl. Linux/CI)

The shared chassis (`LearningKit`) and this app's domain (`StoryTimeCore`: the Story
model, `StoryValidator`, and the errorless `StorySession`) are plain Swift + Foundation,
so they build and unit-test without a Mac:

```bash
swift build
swift test
```

The suite (32 tests, all green) genuinely exercises the **whole core loop** at the model
level — listen → answer → wrong-tap-re-models-and-retries (hammered 25×, never fails) →
reread draws a fresh question set → every beat permutation is accepted → replay → end —
plus decodability/asset/answer validation and the 5 authored stories all passing
`StoryValidator`, plus the mastery/review service.

This is wired into CI (`.github/workflows/ci.yml`, job `core-tests-linux`, container
`swift:6.0.3`).

## 2. The SwiftUI app — requires macOS + Xcode + an iPad simulator

There is no Xcode GUI in the headless build environment, and iOS simulators are
macOS-only, so the visual app is built and driven on a Mac (or the macOS CI job):

```bash
brew install xcodegen          # once
xcodegen generate              # project.yml -> StoryTime.xcodeproj

xcodebuild -scheme StoryTime \
  -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M4)' \
  build

# Boot, install, launch
xcrun simctl boot "iPad Pro 11-inch (M4)" || true
open -a Simulator
xcrun simctl install booted "$(find ~/Library/Developer/Xcode/DerivedData -name 'StoryTime.app' -path '*Debug-iphonesimulator*' | head -1)"
xcrun simctl launch booted com.dsamin.storytime
```

### Driving the loop end-to-end (XCUITest)

`App/StoryTimeUITests/CoreLoopUITests.swift` drives the real UI on the simulator:

```bash
xcodebuild -scheme StoryTime \
  -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M4)' \
  test
```

It taps a wordless tile → waits for the story to play and "your turn" to appear → taps a
**wrong** picture and asserts no alert/fail and the question persists → answers through
both turns (the reread shows a fresh set) → drags the beat cards into the wells → plays
the replay → reaches the calm end card → taps back to the shelf. It also asserts the
parent gate ignores a single stray tap and that the app is landscape.

> The synthesizer placeholder voice (`AVSpeechSynthesizer`) means the entire loop runs
> before any human-voice clip is recorded. Drop `line_<storyId>_<n>.m4a` / `pic_<id>`
> assets into the app bundle later and the engine uses them automatically.
