import SwiftUI
import StoryTimeCore

/// "Your turn." The story art shrinks to a banner; a pulsing orb stands in for the spoken
/// prompt; below are 2–4 large picture choices. A correct tap is confirmed (sage) and
/// expanded by voice; a wrong tap is never punished — the correct choice softly pulses in
/// blue while the voice re-models, then the child tries again.
struct QuestionCardView: View {
    @Bindable var flow: StoryFlowModel

    private let columns = [GridItem(.adaptive(minimum: 200, maximum: 300), spacing: 24)]

    var body: some View {
        VStack(spacing: 22) {
            banner
            HStack(spacing: 20) {
                ListenOrb(tint: orbTint)
                RoundControl(symbol: "speaker.wave.2", action: { flow.repeatPrompt() })
                    .scaleEffect(0.7)
            }

            if let q = flow.currentQuestion {
                LazyVGrid(columns: columns, spacing: 24) {
                    ForEach(q.choices, id: \.self) { ref in
                        ChoiceCard(ref: ref, feedback: feedback(for: ref, in: q)) {
                            flow.tap(choice: ref)
                        }
                        .frame(height: 220)
                        // Encodes correctness for UI testing only (the child has no labels).
                        .accessibilityIdentifier(ref == q.answer ? "choice_correct" : "choice_wrong_\(ref)")
                    }
                }
                .padding(.horizontal, 28)
            }
            Spacer(minLength: 0)
        }
        .padding(28)
        .accessibilityIdentifier("screen_question")
    }

    private var banner: some View {
        HStack(spacing: 16) {
            ForEach(Array(flow.story.cast.prefix(3)), id: \.self) { ref in
                AssetImage(ref: ref).frame(width: 84, height: 84)
            }
        }
        .padding(.horizontal, 24).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Palette.surfaceAlt))
    }

    private var orbTint: Color {
        if case .asking(_, _, .remodel) = flow.phase { return Palette.remodel }
        if case .asking(_, _, .confirmed) = flow.phase { return Palette.confirm }
        return Palette.wordActive
    }

    private func feedback(for ref: String, in q: Question) -> ChoiceCard.Feedback {
        switch flow.phase {
        case .asking(_, _, .confirmed):
            return ref == flow.lastTappedChoice ? .confirmed : .none
        case let .asking(_, _, .remodel(correct)):
            return ref == correct ? .remodel : .none
        default:
            return .none
        }
    }
}
