import Foundation

/// Loads the authored stories from bundled JSON. The same JSON ships in the app bundle
/// and in the package's resource bundle, so the loader works in the app and in tests.
public enum StoryLibrary {

    public enum LoadError: Error, CustomStringConvertible {
        case storiesDirectoryNotFound
        case decodingFailed(file: String, underlying: Error)

        public var description: String {
            switch self {
            case .storiesDirectoryNotFound: return "could not locate the bundled stories/ directory"
            case let .decodingFailed(f, e): return "failed to decode \(f): \(e)"
            }
        }
    }

    /// The bundle that carries the `stories/` resource directory (the package bundle).
    public static var resourceBundle: Bundle { Bundle.module }

    /// All authored stories, sorted by id, decoded from the bundled JSON. Pass a bundle
    /// to load from elsewhere; defaults to the package resource bundle.
    public static func loadAll(from bundle: Bundle? = nil) throws -> [Story] {
        let urls = try storyURLs(in: bundle ?? .module)
        let decoder = JSONDecoder()
        var stories: [Story] = []
        for url in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            do {
                let data = try Data(contentsOf: url)
                stories.append(try decoder.decode(Story.self, from: data))
            } catch {
                throw LoadError.decodingFailed(file: url.lastPathComponent, underlying: error)
            }
        }
        return stories.sorted { $0.id < $1.id }
    }

    private static func storyURLs(in bundle: Bundle) throws -> [URL] {
        // Resources are copied as a directory ("stories"), so look it up as a subdir.
        if let urls = bundle.urls(forResourcesWithExtension: "json", subdirectory: "stories"), !urls.isEmpty {
            return urls.map { $0 as URL }
        }
        if let dir = bundle.url(forResource: "stories", withExtension: nil) {
            let contents = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            let jsons = contents.filter { $0.pathExtension == "json" }
            if !jsons.isEmpty { return jsons }
        }
        throw LoadError.storiesDirectoryNotFound
    }
}
