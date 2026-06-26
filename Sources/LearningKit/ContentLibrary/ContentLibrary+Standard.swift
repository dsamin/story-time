import Foundation

extension ContentLibrary {

    /// The fixed reusable cast for the slate. Adding a story reuses these — no new art.
    public static let castIDs = ["cat", "dog", "pig", "boy"]

    /// The standard shared library: the fixed cast, a set of decodable prop/place
    /// pictures used as picture-answer choices and beat images, and the decodable
    /// word inventory + glue whitelist. This is the single source of truth the
    /// authored stories and `StoryValidator` agree on.
    public static let standard: ContentLibrary = {
        func pic(_ id: String, _ name: String, _ tags: [String]) -> Asset {
            Asset(id: id, kind: .picture, displayName: name, resourceName: "pic_\(id)", tags: tags)
        }

        let pictures: [Asset] = [
            // Cast (the "who")
            pic("cat", "the cat", ["who", "animal", "cast"]),
            pic("dog", "the dog", ["who", "animal", "cast"]),
            pic("pig", "the pig", ["who", "animal", "cast"]),
            pic("boy", "the boy", ["who", "cast"]),
            // More animals usable as distractor "who" choices
            pic("hen", "the hen", ["who", "animal"]),
            pic("fox", "the fox", ["who", "animal"]),
            pic("bug", "the bug", ["who", "animal"]),
            // Places (the "where") and props (the "what")
            pic("mat", "the mat", ["where", "what", "thing"]),
            pic("bed", "the bed", ["where", "what", "thing"]),
            pic("box", "the box", ["where", "what", "thing"]),
            pic("rug", "the rug", ["where", "what", "thing"]),
            pic("den", "the den", ["where", "place"]),
            pic("log", "the log", ["where", "what", "thing"]),
            pic("mud", "the mud", ["where", "what", "thing"]),
            pic("pen", "the pen", ["where", "place"]),
            pic("sun", "the sun", ["what", "thing"]),
            pic("hat", "the hat", ["what", "thing"]),
            pic("cup", "the cup", ["what", "thing"]),
            pic("jam", "the jam", ["what", "thing"]),
            pic("pot", "the pot", ["what", "thing"]),
            pic("net", "the net", ["what", "thing"]),
            pic("bus", "the bus", ["what", "thing"]),
            pic("ham", "the ham", ["what", "food"]),
            pic("bun", "the bun", ["what", "food"]),
        ]

        // CVC-and-friends words a 4-year-old can decode. The validator enforces that
        // every non-glue word in a story line is in this set.
        let decodable: Set<String> = [
            // nouns
            "cat", "dog", "pig", "boy", "hen", "fox", "bug", "mat", "bed", "box",
            "rug", "den", "log", "mud", "pen", "sun", "hat", "cup", "jam", "pot",
            "net", "bus", "ham", "bun", "lap", "top", "cob", "web", "nap", "dig",
            "hug", "tug", "sip", "pat", "hop", "jog", "pup", "kit",
            // verbs (incl. simple inflections)
            "sat", "ran", "hid", "got", "fed", "led", "set", "dug", "let", "had",
            "sits", "naps", "digs", "hops", "runs", "tugs", "sips", "pats", "hugs",
            "jogs", "taps", "tap", "naps", "wins", "win", "dips", "dip", "fits",
            "fit", "rips", "rip", "begs", "beg",
            // adjectives / describers
            "big", "hot", "wet", "red", "sad", "fun", "mad", "fat", "dim", "tan",
            "soft", "fast",
        ]

        // Tiny high-frequency whitelist: spoken, never expected to be decoded.
        let glue: Set<String> = ["the", "a", "is", "on", "in", "and", "to", "his", "was", "it"]

        return ContentLibrary(assets: pictures, decodableWords: decodable, glueWords: glue)
    }()
}
