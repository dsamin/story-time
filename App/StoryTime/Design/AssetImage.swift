import SwiftUI
import UIKit
import LearningKit

/// Renders the placeholder art for a content-library picture id. Real commissioned art
/// is deferred (README); until then each asset maps to a recognisable SF Symbol + a
/// stable muted tint, so the loop is fully playable and wordless. When real art lands,
/// `pic_<id>` image assets in the app bundle override this automatically.
struct AssetImage: View {
    let ref: String
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Self.tint(for: ref).opacity(0.22))
            // Prefer real bundled art if present; else the symbol placeholder.
            if UIImage(named: "pic_\(ref)") != nil {
                Image("pic_\(ref)").resizable().scaledToFit().padding(18)
            } else {
                Image(systemName: Self.symbol(for: ref))
                    .resizable().scaledToFit()
                    .fontWeight(.regular)
                    .foregroundStyle(Self.tint(for: ref))
                    .padding(28)
            }
        }
        .accessibilityHidden(true) // the child is guided by audio, not labels
    }

    static func symbol(for ref: String) -> String {
        let map: [String: String] = [
            "cat": "cat.fill", "dog": "dog.fill", "pig": "pawprint.fill", "boy": "figure.child",
            "hen": "bird.fill", "fox": "pawprint.circle.fill", "bug": "ladybug.fill",
            "mat": "rectangle.portrait.fill", "bed": "bed.double.fill", "box": "shippingbox.fill",
            "rug": "rectangle.fill", "den": "house.fill", "log": "tree.fill", "mud": "drop.fill",
            "pen": "square.dashed", "sun": "sun.max.fill", "hat": "graduationcap.fill",
            "cup": "cup.and.saucer.fill", "jam": "takeoutbag.and.cup.and.straw.fill",
            "pot": "frying.pan.fill", "net": "net", "bus": "bus.fill",
            "ham": "fork.knife", "bun": "birthday.cake.fill",
        ]
        return map[ref] ?? "questionmark.circle"
    }

    static func tint(for ref: String) -> Color {
        let tints: [Color] = [Palette.confirm, Palette.accent, Palette.remodel, Palette.wordActive, Palette.wordUnspoken]
        var hash = 5381
        for b in ref.utf8 { hash = ((hash << 5) &+ hash) &+ Int(b) }
        return tints[abs(hash) % tints.count]
    }
}
