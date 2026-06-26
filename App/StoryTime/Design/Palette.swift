import SwiftUI

/// The "Lamplit Storybook" palette (see docs/DESIGN.md). Muted, lamp-warmed tones over
/// near-paper. The re-model tint is soft blue, never red — a wrong tap says "let me show
/// you again," not "wrong."
enum Palette {
    static let background      = Color(hex: 0xEDE7DC)   // warm paper
    static let surface         = Color(hex: 0xF4F0E8)   // lifted paper / cards
    static let surfaceAlt      = Color(hex: 0xE2DACB)   // recessed wells / banner
    static let ink             = Color(hex: 0x4A4A4A)   // parent-gate text only
    static let wordActive      = Color(hex: 0xE6C36A)   // gold spoken-word highlight
    static let wordActiveGlow  = Color(hex: 0xF2E0AE)   // halo behind the gold chip
    static let confirm         = Color(hex: 0x8FB9A8)   // sage "yes"
    static let remodel         = Color(hex: 0xA9C8E0)   // soft blue "let me show you"
    static let accent          = Color(hex: 0xC9A8D8)   // lavender 1·2·3 dots / quiet UI
    static let wordSpoken       = Color(hex: 0x9A9183)   // settled (already spoken)
    static let wordUnspoken     = Color(hex: 0x6A6258)   // unspoken / caption ink
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue:  Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
