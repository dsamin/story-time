import SwiftUI
import StoryTimeCore

/// The story replays as a calm montage assembled from the child's ordering: each beat
/// fades and scales in 1→2→3 while the voice narrates it. Recalling the story *is* the
/// memory exercise; watching it play back is the reward. No flourish, no score.
struct ReplayView: View {
    @Bindable var flow: StoryFlowModel

    private var order: [String] {
        if case let .replay(order) = flow.phase { return order }
        return flow.story.beats.map(\.id)
    }

    var body: some View {
        VStack(spacing: 28) {
            ListenOrb().scaleEffect(0.7)
            HStack(spacing: 24) {
                ForEach(Array(order.enumerated()), id: \.offset) { idx, ref in
                    AssetImage(ref: beatImage(ref))
                        .frame(width: 220, height: 220)
                        .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Palette.surface))
                        .opacity(shown(idx) ? 1 : 0)
                        .scaleEffect(shown(idx) ? 1 : 0.96)
                }
            }
        }
        .padding(36)
        .onAppear { flow.startReplay() }
    }

    private func shown(_ idx: Int) -> Bool {
        guard let active = flow.replayBeatIndex else { return false }
        return idx <= active
    }

    private func beatImage(_ id: String) -> String {
        flow.story.beats.first { $0.id == id }?.image ?? id
    }
}
