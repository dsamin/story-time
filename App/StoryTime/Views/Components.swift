import SwiftUI

/// A calm press-down for tappable cards/tiles — a gentle scale, no bounce.
struct PressableStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.97
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .animation(.easeInOut(duration: 0.18), value: configuration.isPressed)
    }
}

/// A single word in the narrated line. Exactly one chip is gold (currently spoken) at a
/// time; already-spoken words settle to warm gray; tapping any chip re-speaks that word.
struct WordChip: View {
    enum State { case unspoken, active, spoken }
    let text: String
    let state: State
    let onTap: () -> Void

    var body: some View {
        Text(text)
            .font(.system(size: 34, weight: .semibold, design: .rounded))
            .foregroundStyle(textColor)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(state == .active ? Palette.wordActive : .clear)
            )
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Palette.wordActiveGlow.opacity(state == .active ? 0.4 : 0))
                    .blur(radius: 8)
            )
            .scaleEffect(state == .active ? 1.06 : 1)
            .onTapGesture(perform: onTap)
            .accessibilityHidden(true)
    }

    private var textColor: Color {
        switch state {
        case .unspoken: return Palette.wordUnspoken
        case .active:   return Palette.ink
        case .spoken:   return Palette.wordSpoken
        }
    }
}

/// The "listen" indicator — a gentle pulsing gold sound-wave orb. It is the visual
/// stand-in for a spoken prompt (the child listens rather than reads).
struct ListenOrb: View {
    var tint: Color = Palette.wordActive
    @State private var pulse = false
    var body: some View {
        ZStack {
            Circle().fill(tint.opacity(0.18)).frame(width: 92, height: 92)
                .scaleEffect(pulse ? 1.12 : 0.96)
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(tint)
        }
        .onAppear { withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true } }
        .accessibilityHidden(true)
    }
}

/// A large circular control (replay, repeat).
struct RoundControl: View {
    let symbol: String
    let action: () -> Void
    var tint: Color = Palette.wordActive
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(Palette.surface)
                    .overlay(Circle().stroke(tint, lineWidth: 3))
                    .frame(width: 88, height: 88)
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
                Image(systemName: symbol)
                    .font(.system(size: 34, weight: .regular))
                    .foregroundStyle(tint)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(symbol))
    }
}

/// A large picture-answer choice card. Errorless feedback is expressed here.
struct ChoiceCard: View {
    enum Feedback: Equatable { case none, confirmed, remodel }
    let ref: String
    let feedback: Feedback
    let onTap: () -> Void
    @State private var pressed = false

    var body: some View {
        Button(action: onTap) {
            AssetImage(ref: ref)
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Palette.surface)
                        .shadow(color: .black.opacity(0.06), radius: 12, y: 5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(borderColor, lineWidth: feedback == .none ? 0 : 5)
                )
                .scaleEffect(scale)
        }
        .buttonStyle(.plain)
        .animation(feedback == .confirmed ? Motion.confirm : Motion.remodel, value: feedback)
    }

    private var borderColor: Color {
        switch feedback {
        case .none: return .clear
        case .confirmed: return Palette.confirm
        case .remodel: return Palette.remodel
        }
    }
    private var scale: CGFloat {
        switch feedback {
        case .confirmed: return 1.04
        case .remodel: return 1.03
        case .none: return pressed ? 0.98 : 1
        }
    }
}
