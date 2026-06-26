import SwiftUI
import SwiftData
import LearningKit
import StoryTimeCore

/// Top-level app state: the validated story list, the shared chassis (library, narrator,
/// mastery), and which screen is showing. Fully on-device; no networking exists anywhere.
@Observable
final class AppModel {
    let library = ContentLibrary.standard
    let validator = StoryValidator()
    let mastery = MasteryService()
    let narrator: Narrator

    /// Only stories that pass validation are ever surfaced to the child.
    private(set) var allStories: [Story] = []

    enum Screen: Equatable {
        case shelf
        case playing(storyID: String)
    }
    var screen: Screen = .shelf
    var showingParentSettings = false

    /// The currently-running story flow, owned here so it survives view re-renders.
    @ObservationIgnored private(set) var activeFlow: StoryFlowModel?

    @ObservationIgnored var settings: ParentSettings?
    @ObservationIgnored var context: ModelContext?

    init() {
        if ProcessInfo.processInfo.arguments.contains("-uiTesting") {
            // Deterministic, fast narration for the headless UI-test simulator.
            self.narrator = UITestNarrator()
        } else {
            // Recorded human-voice clips when present; the synth placeholder otherwise, so
            // the whole loop runs before any audio is recorded.
            let synth = SynthNarrator()
            self.narrator = ClipNarrator(bundle: .main, fallback: synth)
        }
        loadStories()
    }

    private func loadStories() {
        let loaded = (try? StoryLibrary.loadAll(from: .main)) ?? (try? StoryLibrary.loadAll()) ?? []
        allStories = loaded.filter { validator.isValid($0) }
    }

    /// Stories shown on the shelf (active, valid).
    var shelfStories: [Story] {
        let disabled = Set(settings?.disabledStoryIDs ?? [])
        return allStories.filter { !disabled.contains($0.id) }
    }

    func story(id: String) -> Story? { allStories.first { $0.id == id } }

    func attach(context: ModelContext) {
        self.context = context
        let existing = (try? context.fetch(FetchDescriptor<ParentSettings>()))?.first
        let s = existing ?? ParentSettings()
        if existing == nil { context.insert(s) }
        s.loadMastery(into: mastery)
        self.settings = s
        applyVoice()
    }

    func applyVoice() {
        if let synth = (narrator as? ClipNarrator)?.fallback as? SynthNarrator {
            synth.rate = 0.42
        }
    }

    func persist() {
        settings?.saveMastery(from: mastery)
        try? context?.save()
    }

    func open(storyID: String) {
        guard let story = story(id: storyID) else { return }
        activeFlow = StoryFlowModel(
            story: story,
            narrator: narrator,
            mastery: mastery,
            library: library,
            onExit: { [weak self] in self?.returnToShelf() }
        )
        withAnimation(Motion.screen) { screen = .playing(storyID: storyID) }
    }

    func returnToShelf() {
        persist()
        activeFlow = nil
        withAnimation(Motion.screen) { screen = .shelf }
    }
}
