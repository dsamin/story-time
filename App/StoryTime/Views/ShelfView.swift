import SwiftUI
import LearningKit
import StoryTimeCore

/// The wordless home: a shelf of large story tiles, each showing its cast. Tapping a tile
/// names it in the warm voice, then opens the story. The only way to settings is the
/// press-and-hold-then-drag gate, so a child cannot stumble in.
struct ShelfView: View {
    @Environment(AppModel.self) private var model

    private let columns = [GridItem(.adaptive(minimum: 240, maximum: 320), spacing: 28)]

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 28) {
                    ForEach(model.shelfStories) { story in
                        StoryTile(story: story) { open(story) }
                            .accessibilityIdentifier("tile_\(story.id)")
                    }
                }
                .padding(40)
            }

            ParentGate { model.showingParentSettings = true }
                .padding(28)
                .accessibilityIdentifier("parentGate")
        }
    }

    private func open(_ story: Story) {
        // Name the tile, then open — every action is spoken.
        model.narrator.speak(.phrase(spokenName(for: story)))
        model.open(storyID: story.id)
    }

    private func spokenName(for story: Story) -> String {
        let names = story.cast.compactMap { model.library.picture($0)?.displayName }
        return names.isEmpty ? story.title : names.joined(separator: " and ")
    }
}

private struct StoryTile: View {
    @Environment(AppModel.self) private var model
    let story: Story
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Palette.surface)
                    .shadow(color: .black.opacity(0.06), radius: 14, y: 6)
                castArt
                    .padding(26)
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(story.title) // adult/VoiceOver only; child is guided by audio
    }

    private var castArt: some View {
        let cast = Array(story.cast.prefix(3))
        return ZStack {
            ForEach(Array(cast.enumerated()), id: \.offset) { idx, ref in
                AssetImage(ref: ref)
                    .frame(width: idx == 0 ? 150 : 92, height: idx == 0 ? 150 : 92)
                    .offset(x: CGFloat(idx) * 46 - CGFloat(cast.count - 1) * 23,
                            y: idx == 0 ? 0 : 46)
                    .zIndex(idx == 0 ? 1 : 0)
            }
        }
    }
}
