import SwiftUI

/// A cognitive gate: the adult must press-and-hold the lock (0.6s) **then** drag it
/// sideways to open settings. A single tap — all a 4-year-old is likely to do — does
/// nothing. There is no one-tap "are you a grown-up?" dialog.
struct ParentGate: View {
    let onUnlock: () -> Void

    @State private var holding = false
    @State private var dragProgress: CGFloat = 0   // 0…1 once holding begins

    private let dragDistance: CGFloat = 96

    var body: some View {
        ZStack {
            Circle()
                .fill(Palette.surface)
                .overlay(Circle().stroke(Palette.accent.opacity(holding ? 0.9 : 0.3), lineWidth: 2))
                .frame(width: 56, height: 56)
                .shadow(color: .black.opacity(0.06), radius: 8, y: 3)

            Image(systemName: holding ? "lock.open" : "lock")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(Palette.accent)
                .offset(x: dragProgress * dragDistance)
        }
        .opacity(0.55 + 0.45 * Double(holding ? 1 : 0))
        .gesture(gate)
        .accessibilityLabel("Grown-ups")
        .accessibilityHint("Press and hold, then slide to open settings")
    }

    private var gate: some Gesture {
        LongPressGesture(minimumDuration: 0.6)
            .onEnded { _ in withAnimation(.easeInOut(duration: 0.3)) { holding = true } }
            .sequenced(before: DragGesture(minimumDistance: 10))
            .onChanged { value in
                guard case let .second(_, drag?) = value else { return }
                dragProgress = min(1, max(0, drag.translation.width / dragDistance))
            }
            .onEnded { _ in
                let unlocked = dragProgress > 0.7
                withAnimation(.easeInOut(duration: 0.3)) { holding = false; dragProgress = 0 }
                if unlocked { onUnlock() }
            }
    }
}
