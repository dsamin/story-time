import SwiftUI

/// Calm motion constants (see docs/DESIGN.md). All easeInOut, slow, no spring/bounce —
/// nothing celebratory.
enum Motion {
    static let wordAdvance  = Animation.easeInOut(duration: 0.45)
    static let confirm      = Animation.easeInOut(duration: 0.70)
    static let remodel      = Animation.easeInOut(duration: 0.80)
    static let drop         = Animation.easeInOut(duration: 0.50)
    static let replayBeat   = Animation.easeInOut(duration: 0.60)
    static let screen       = Animation.easeInOut(duration: 0.50)

    /// The default calm transition for swapping screens/cards.
    static let transition: AnyTransition = .opacity.combined(with: .scale(scale: 0.98))
}
