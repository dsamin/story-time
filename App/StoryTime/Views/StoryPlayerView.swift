import SwiftUI
import StoryTimeCore

/// The narrated story: a big illustration, the line of word chips highlighting one-by-one
/// as spoken (tap any word to replay it), and a large replay control. Auto-advances to the
/// questions when the story finishes; the child can replay as often as they like.
struct StoryPlayerView: View {
    @Bindable var flow: StoryFlowModel

    private var line: Line? {
        guard let i = flow.activeLine, i < flow.story.lines.count else { return flow.story.lines.first }
        return flow.story.lines[i]
    }

    var body: some View {
        VStack(spacing: 18) {
            illustration
                .frame(maxWidth: .infinity)
                .frame(maxHeight: .infinity)

            wordLine
                .frame(minHeight: 90)

            RoundControl(symbol: "arrow.counterclockwise") { flow.replayStory() }
                .padding(.bottom, 8)
                .accessibilityIdentifier("replayStory")
        }
        .padding(28)
        .accessibilityIdentifier("screen_player")
        .onAppear { flow.beginListeningIfNeeded() }
    }

    private var illustration: some View {
        let beatImage = currentBeatImage
        return AssetImage(ref: beatImage)
            .frame(maxWidth: 620)
            .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
            .id(beatImage)
            .transition(.opacity)
    }

    private var currentBeatImage: String {
        guard let line, let beat = flow.story.beats.first(where: { $0.id == line.beat }) else {
            return flow.story.cast.first ?? "cat"
        }
        return beat.image
    }

    private var wordLine: some View {
        let lineIndex = flow.activeLine ?? 0
        let words = line?.words ?? []
        return HStack(spacing: 6) {
            ForEach(Array(words.enumerated()), id: \.offset) { idx, word in
                WordChip(text: word.text, state: chipState(idx), onTap: {
                    flow.speakWord(line: lineIndex, word: idx)
                })
            }
        }
    }

    private func chipState(_ idx: Int) -> WordChip.State {
        guard let active = flow.activeWord else { return .unspoken }
        if idx == active { return .active }
        return idx < active ? .spoken : .unspoken
    }
}
