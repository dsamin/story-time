import SwiftUI

/// A soft, quiet resting screen. No score, no stars, no "play again?" nag. A single tap
/// anywhere returns to the shelf.
struct EndCardView: View {
    @Bindable var flow: StoryFlowModel
    @State private var appeared = false

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            VStack(spacing: 24) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 72, weight: .regular))
                    .foregroundStyle(Palette.confirm)
                    .opacity(appeared ? 0.9 : 0)
                Image(systemName: "house.fill")
                    .font(.system(size: 34, weight: .regular))
                    .foregroundStyle(Palette.accent)
                    .opacity(appeared ? 0.6 : 0)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { flow.exit() }
        .accessibilityIdentifier("endCard")
        .onAppear { withAnimation(.easeInOut(duration: 0.9)) { appeared = true } }
        .accessibilityLabel("The end. Tap to go back.")
    }
}
