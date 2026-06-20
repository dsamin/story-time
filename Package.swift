// swift-tools-version: 5.9
import PackageDescription

// LearningKit  — the shared, app-agnostic chassis (ContentLibrary, AudioEngine,
//                ReviewService). No app-specific imports; extraction-ready.
// StoryTimeCore — this app's pure domain: the Story model, StoryValidator, and the
//                 errorless StorySession state machine, plus the authored stories.
//
// Both targets build and unit-test on Linux (plain Swift + Foundation); Apple-only
// narrators/persistence in the app sit behind `#if canImport(...)`. The SwiftUI app
// (App/StoryTime, built by the Xcode project) consumes these products.
let package = Package(
    name: "StoryTime",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "LearningKit", targets: ["LearningKit"]),
        .library(name: "StoryTimeCore", targets: ["StoryTimeCore"]),
    ],
    targets: [
        .target(
            name: "LearningKit",
            path: "Sources/LearningKit"
        ),
        .target(
            name: "StoryTimeCore",
            dependencies: ["LearningKit"],
            path: "Sources/StoryTimeCore",
            resources: [.copy("Resources/stories")]
        ),
        .testTarget(
            name: "LearningKitTests",
            dependencies: ["LearningKit"],
            path: "Tests/LearningKitTests"
        ),
        .testTarget(
            name: "StoryTimeCoreTests",
            dependencies: ["StoryTimeCore", "LearningKit"],
            path: "Tests/StoryTimeCoreTests"
        ),
    ]
)
