import SwiftUI
import StoryTimeCore
import LearningKit

/// Adult-facing settings, reached only through the press-and-hold-then-drag gate. This is
/// the one place readable text lives. Voice, reduce-motion, which stories are active, and a
/// peek at what the review service thinks needs another pass.
struct ParentSettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                if let settings = model.settings {
                    SettingsControls(settings: settings, stories: model.allStories)
                }
                Section("Needs another pass") {
                    let due = storiesDue()
                    if due.isEmpty {
                        Text("Nothing due right now.").foregroundStyle(.secondary)
                    } else {
                        ForEach(due, id: \.self) { title in
                            Label(title, systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                }
            }
            .navigationTitle("Grown-ups")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { model.persist(); dismiss() }
                }
            }
        }
    }

    private func storiesDue() -> [String] {
        var storyTargets: [String: Set<MasteryService.Target>] = [:]
        for story in model.allStories {
            var targets = Set<MasteryService.Target>()
            for q in story.questionSets {
                targets.insert(.init(kind: .comprehension, id: "\(story.id):\(q.type.rawValue)"))
                targets.insert(.init(kind: .vocabulary, id: q.answer))
            }
            storyTargets[story.id] = targets
        }
        return model.mastery.storiesDue(storyTargets).compactMap { model.story(id: $0)?.title }
    }
}

private struct SettingsControls: View {
    @Bindable var settings: ParentSettings
    let stories: [Story]

    var body: some View {
        Section("Voice") {
            HStack {
                Image(systemName: "speaker.fill")
                Slider(value: $settings.voiceVolume, in: 0...1)
                Image(systemName: "speaker.wave.3.fill")
            }
        }
        Section("Calm") {
            Toggle("Reduce motion", isOn: $settings.reduceMotion)
        }
        Section("Stories") {
            ForEach(stories) { story in
                Toggle(story.title, isOn: activeBinding(for: story))
            }
        }
    }

    private func activeBinding(for story: Story) -> Binding<Bool> {
        Binding(
            get: { !settings.disabledStoryIDs.contains(story.id) },
            set: { active in
                if active { settings.disabledStoryIDs.removeAll { $0 == story.id } }
                else if !settings.disabledStoryIDs.contains(story.id) { settings.disabledStoryIDs.append(story.id) }
            }
        )
    }
}
