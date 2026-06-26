import SwiftUI
import StoryTimeCore

/// Hosts one story's run through the errorless loop, swapping the screen by phase. Every
/// transition is calm; there is no score, timer, or fail screen anywhere in here.
struct StoryFlowView: View {
    let flow: StoryFlowModel

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            content
                .transition(Motion.transition)
        }
        .animation(Motion.screen, value: phaseKey)
    }

    @ViewBuilder private var content: some View {
        switch flow.phase {
        case .listening:
            StoryPlayerView(flow: flow)
        case .asking:
            QuestionCardView(flow: flow)
        case .sequencing:
            SequencingBoardView(flow: flow)
        case .replay:
            ReplayView(flow: flow)
        case .end:
            EndCardView(flow: flow)
        }
    }

    /// A stable key so the calm cross-fade only fires on real screen changes.
    private var phaseKey: Int {
        switch flow.phase {
        case .listening(let r): return 100 + r
        case .asking(let t, let q, _): return 200 + t * 10 + q
        case .sequencing: return 300
        case .replay: return 400
        case .end: return 500
        }
    }
}
