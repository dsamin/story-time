import Foundation

/// A story is pure data: text plus references into the `ContentLibrary`. Adding a
/// story means writing one JSON file against this shape — no new art, no code.
public struct Story: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    /// Adult-facing only; never shown to the child.
    public let title: String
    /// Picture refs into ContentLibrary — the story's cast (drives the shelf tile).
    public let cast: [String]
    /// Narrated in order; words flagged for highlighting.
    public let lines: [Line]
    /// 2–3 ordered story beats → the sequencing cards (this is the canonical order).
    public let beats: [Beat]
    /// Flat list of spoken questions. The first read asks the first half; the reread
    /// asks the second half (a genuinely new set). Floor: ≥2.
    public let questionSets: [Question]

    public init(id: String, title: String, cast: [String], lines: [Line], beats: [Beat], questionSets: [Question]) {
        self.id = id
        self.title = title
        self.cast = cast
        self.lines = lines
        self.beats = beats
        self.questionSets = questionSets
    }
}

/// One narrated line, tied to a story beat.
public struct Line: Codable, Sendable, Equatable {
    public let words: [Word]
    /// Which beat id this line belongs to.
    public let beat: String

    public init(words: [Word], beat: String) {
        self.words = words
        self.beat = beat
    }

    /// The line as a single spoken string.
    public var text: String { words.map(\.text).joined(separator: " ") }
}

/// One word in a line. `glue` words are spoken but not expected to be decoded.
public struct Word: Codable, Sendable, Equatable {
    public let text: String
    public let glue: Bool

    public init(text: String, glue: Bool = false) {
        self.text = text
        self.glue = glue
    }
}

/// A story beat: an image and a (spoken, adult-modeled) caption. Beats become the
/// shuffled sequencing cards and the assembled-replay frames.
public struct Beat: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    /// Picture ref into ContentLibrary.
    public let image: String
    /// Spoken when this beat replays; decorative if ever shown.
    public let caption: String

    public init(id: String, image: String, caption: String) {
        self.id = id
        self.image = image
        self.caption = caption
    }
}

public enum QuestionType: String, Codable, Sendable {
    case who, what
    case `where`
}

/// A single spoken question answered by tapping a picture.
public struct Question: Codable, Sendable, Equatable, Identifiable {
    /// SPOKEN to the child, never read by them.
    public let prompt: String
    public let type: QuestionType
    /// Picture refs; exactly one is the answer.
    public let choices: [String]
    /// Picture ref; must be one of `choices`.
    public let answer: String
    /// Spoken on a correct tap — models a fuller sentence (dialogic expansion).
    public let expansion: String

    public var id: String { prompt }

    public init(prompt: String, type: QuestionType, choices: [String], answer: String, expansion: String) {
        self.prompt = prompt
        self.type = type
        self.choices = choices
        self.answer = answer
        self.expansion = expansion
    }
}

public extension Story {
    /// The beats in their canonical (authored) order — the "correct" sequence the
    /// replay uses if the child happens to match it. (Any order is accepted, though.)
    var canonicalBeatOrder: [String] { beats.map(\.id) }

    /// Split the flat question list into per-read "turns". Turn 0 is the first read,
    /// turn 1 the reread; each gets a disjoint slice so the reread is always fresh.
    func questions(forTurn turn: Int) -> [Question] {
        guard !questionSets.isEmpty else { return [] }
        let half = max(1, questionSets.count / 2)
        if turn <= 0 {
            return Array(questionSets.prefix(half))
        } else {
            let rest = Array(questionSets.dropFirst(half))
            return rest.isEmpty ? Array(questionSets.suffix(half)) : rest
        }
    }
}
