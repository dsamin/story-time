import SwiftUI

/// The wordless top level: the story shelf, with a story flow pushed over it when a tile
/// is tapped, and the gated parent settings presented as a sheet.
struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        return ZStack {
            Palette.background.ignoresSafeArea()

            switch model.screen {
            case .shelf:
                ShelfView()
                    .transition(Motion.transition)
            case let .playing(storyID):
                if let flow = model.activeFlow {
                    StoryFlowView(flow: flow)
                        .id(storyID)
                        .transition(Motion.transition)
                }
            }
        }
        .sheet(isPresented: $model.showingParentSettings) {
            ParentSettingsView()
                .environment(model)
        }
    }
}
