import Foundation

/// A tagged word / sound / picture database shared across the learning-app slate.
///
/// `ContentLibrary` is pure data with no app-specific imports, so it lifts cleanly
/// into the shared `LearningKit` package. Stories reference library entries by id,
/// so "the dog" is the same asset every app shows.
public struct ContentLibrary: Sendable {

    /// What kind of thing an asset is.
    public enum Kind: String, Codable, Sendable {
        case picture
        case word
        case sound
    }

    /// One tagged entry in the library.
    public struct Asset: Identifiable, Codable, Sendable, Equatable {
        public let id: String
        public let kind: Kind
        /// Adult-facing label (e.g. for the parent settings list). Never shown to the child.
        public let displayName: String
        /// Name of the bundled art/audio resource the app renders for this asset.
        public let resourceName: String
        /// Free-form tags used for filtering / authoring (e.g. "animal", "who", "place").
        public let tags: [String]

        public init(id: String, kind: Kind, displayName: String, resourceName: String, tags: [String] = []) {
            self.id = id
            self.kind = kind
            self.displayName = displayName
            self.resourceName = resourceName
            self.tags = tags
        }
    }

    private let assetsByID: [String: Asset]

    /// Lowercased words that a 4-year-old is expected to be able to decode.
    public let decodableWords: Set<String>

    /// Lowercased high-frequency "glue" words — spoken, but not expected to be decoded.
    public let glueWords: Set<String>

    public init(assets: [Asset], decodableWords: Set<String>, glueWords: Set<String>) {
        self.assetsByID = Dictionary(uniqueKeysWithValues: assets.map { ($0.id, $0) })
        self.decodableWords = Set(decodableWords.map { $0.lowercased() })
        self.glueWords = Set(glueWords.map { $0.lowercased() })
    }

    // MARK: Lookups

    public var allAssets: [Asset] { Array(assetsByID.values) }

    public func asset(_ id: String) -> Asset? { assetsByID[id] }

    public func picture(_ id: String) -> Asset? {
        guard let a = assetsByID[id], a.kind == .picture else { return nil }
        return a
    }

    public func hasPicture(_ id: String) -> Bool { picture(id) != nil }

    /// Normalises a token the way the validator and narrator do: lowercased and with
    /// surrounding punctuation removed (so "mat!" matches "mat").
    public static func normalize(_ raw: String) -> String {
        raw.lowercased().trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    }

    public func isDecodable(_ word: String) -> Bool {
        decodableWords.contains(Self.normalize(word))
    }

    public func isGlue(_ word: String) -> Bool {
        glueWords.contains(Self.normalize(word))
    }

    /// A word is acceptable in a story line if it is decodable, or a whitelisted glue word.
    public func isSpeakable(_ word: String, glue: Bool) -> Bool {
        let n = Self.normalize(word)
        if n.isEmpty { return false }
        if glue { return glueWords.contains(n) }
        return decodableWords.contains(n)
    }
}
