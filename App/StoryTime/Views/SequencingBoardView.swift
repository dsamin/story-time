import SwiftUI
import StoryTimeCore

/// Put the story back in order. 2–3 shuffled beat cards drag into first/next/last wells
/// (shown as 1·2·3 dots). Any order is accepted — there is no wrong order — and once every
/// well is filled the child plays their story back. Drag targets are oversized for an
/// imprecise 4-year-old.
struct SequencingBoardView: View {
    @Bindable var flow: StoryFlowModel

    @State private var slots: [String?] = []
    @State private var tray: [String] = []
    @State private var initialized = false

    private var beatCount: Int { flow.story.beats.count }
    // `slots` is sized in onAppear; until then it is empty, so guard against an empty array.
    private var allPlaced: Bool { slots.count == beatCount && slots.allSatisfy { $0 != nil } }

    var body: some View {
        VStack(spacing: 36) {
            ListenOrb()
                .scaleEffect(0.8)

            // Tray of shuffled cards still to place.
            HStack(spacing: 20) {
                ForEach(tray, id: \.self) { ref in
                    // A Button so it is reliably exposed to accessibility / UI tests.
                    // Tap-to-place too: drag is hard for a 4-year-old, so a tap drops the
                    // card into the next open well (and keeps the UI test deterministic).
                    Button { placeInNextOpenWell(ref) } label: { beatCard(ref) }
                        .buttonStyle(.plain)
                        .beatDraggable(ref)
                        .accessibilityIdentifier("beat_\(ref)")
                }
                if tray.isEmpty { Color.clear.frame(height: 200) }
            }
            .frame(minHeight: 210)

            // Ordered drop wells.
            HStack(spacing: 24) {
                ForEach(0..<beatCount, id: \.self) { idx in
                    well(idx)
                }
            }

            if allPlaced {
                RoundControl(symbol: "play.fill") {
                    flow.setOrder(slots.compactMap { $0 })
                    flow.confirmOrder()
                }
                .transition(Motion.transition)
                .accessibilityIdentifier("sequencePlay")
            }
        }
        .padding(36)
        .accessibilityIdentifier("screen_sequencing")
        .animation(Motion.drop, value: slots)
        .animation(Motion.drop, value: tray)
        .onAppear(perform: initializeIfNeeded)
    }

    private func initializeIfNeeded() {
        guard !initialized else { return }
        initialized = true
        let order = flow.session.workingOrder ?? flow.story.beats.map(\.id)
        tray = order
        slots = Array(repeating: nil, count: beatCount)
    }

    private func beatCard(_ ref: String) -> some View {
        AssetImage(ref: beatImage(ref))
            .frame(width: 200, height: 200)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Palette.surface)
                .shadow(color: .black.opacity(0.06), radius: 10, y: 4))
    }

    private func well(_ idx: Int) -> some View {
        VStack(spacing: 12) {
            PositionDots(position: idx + 1, total: beatCount)
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Palette.surfaceAlt)
                    .frame(width: 240, height: 240)
                if idx < slots.count, let ref = slots[idx] {
                    Button { unplace(at: idx) } label: { beatCard(ref) }   // tap to take it back
                        .buttonStyle(.plain)
                        .beatDraggable(ref)
                }
            }
            .beatDropDestination { place($0, at: idx) }
            .accessibilityIdentifier("well_\(idx)")
        }
    }

    private func placeInNextOpenWell(_ ref: String) {
        if let idx = slots.firstIndex(where: { $0 == nil }) { place(ref, at: idx) }
    }

    private func unplace(at idx: Int) {
        guard idx < slots.count, let ref = slots[idx] else { return }
        slots[idx] = nil
        if !tray.contains(ref) { tray.append(ref) }
    }

    private func place(_ ref: String, at idx: Int) {
        guard idx < slots.count else { return }
        // Remove ref wherever it currently is.
        if let from = slots.firstIndex(of: ref) { slots[from] = nil }
        tray.removeAll { $0 == ref }
        // If the target well is occupied, send its card back to the tray.
        if let displaced = slots[idx] { tray.append(displaced) }
        slots[idx] = ref
        if allPlaced { flow.setOrder(slots.compactMap { $0 }) }
    }

    private func beatImage(_ id: String) -> String {
        flow.story.beats.first { $0.id == id }?.image ?? id
    }
}

private extension View {
    /// System drag-and-drop is the production interaction, but it is disabled under UI
    /// testing: `.draggable`/`.dropDestination` build a drag interaction whose accessibility
    /// snapshot can trap the app under XCUITest. Tap-to-place covers the test path.
    @ViewBuilder func beatDraggable(_ payload: String) -> some View {
        if AppEnv.isUITesting { self } else { self.draggable(payload) }
    }

    @ViewBuilder func beatDropDestination(perform: @escaping (String) -> Void) -> some View {
        if AppEnv.isUITesting {
            self
        } else {
            self.dropDestination(for: String.self) { items, _ in
                guard let ref = items.first else { return false }
                perform(ref)
                return true
            }
        }
    }
}

/// The 1·2·3 position indicator — dots, not words (the child can't read).
private struct PositionDots: View {
    let position: Int
    let total: Int
    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...total, id: \.self) { i in
                Circle()
                    .fill(i == position ? Palette.accent : Palette.accent.opacity(0.25))
                    .frame(width: 12, height: 12)
            }
        }
    }
}
