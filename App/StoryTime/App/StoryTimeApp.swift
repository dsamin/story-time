import SwiftUI
import SwiftData
import UIKit

@main
struct StoryTimeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .modelContainer(for: ParentSettings.self) { result in
                    if case let .success(container) = result {
                        model.attach(context: container.mainContext)
                    }
                }
        }
    }
}

/// Locks the app to landscape (iPad-only). The Info.plist also declares landscape-only
/// orientations; this enforces it at runtime.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        .landscape
    }
}
