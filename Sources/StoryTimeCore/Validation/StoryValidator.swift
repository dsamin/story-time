import Foundation
import LearningKit

/// A specific reason a story is not authorable-valid. Adult-facing (parent settings
/// can surface these), never the child.
public enum StoryDefect: Equatable, CustomStringConvertible {
    case undecodableWord(lineIndex: Int, word: String)
    case lineReferencesUnknownBeat(lineIndex: Int, beat: String)
    case emptyLine(lineIndex: Int)
    case missingPicture(ref: String, context: String)
    case answerNotInChoices(questionIndex: Int, answer: String)
    case tooFewChoices(questionIndex: Int, count: Int)
    case tooManyChoices(questionIndex: Int, count: Int)
    case duplicateChoice(questionIndex: Int, ref: String)
    case tooFewQuestions(count: Int)
    case beatCountOutOfRange(count: Int)
    case duplicateBeatID(id: String)
    case emptyCast

    public var description: String {
        switch self {
        case let .undecodableWord(i, w): return "line \(i): \"\(w)\" is not decodable and not a glue word"
        case let .lineReferencesUnknownBeat(i, b): return "line \(i): references unknown beat \"\(b)\""
        case let .emptyLine(i): return "line \(i): has no words"
        case let .missingPicture(ref, ctx): return "\(ctx): picture \"\(ref)\" is not in the content library"
        case let .answerNotInChoices(i, a): return "question \(i): answer \"\(a)\" is not among its choices"
        case let .tooFewChoices(i, c): return "question \(i): needs 2–4 choices, has \(c)"
        case let .tooManyChoices(i, c): return "question \(i): needs 2–4 choices, has \(c)"
        case let .duplicateChoice(i, r): return "question \(i): duplicate choice \"\(r)\""
        case let .tooFewQuestions(c): return "needs at least 2 questions (for a fresh reread set), has \(c)"
        case let .beatCountOutOfRange(c): return "needs 2–3 beats, has \(c)"
        case let .duplicateBeatID(id): return "duplicate beat id \"\(id)\""
        case .emptyCast: return "cast is empty"
        }
    }
}

/// Validates an authored story against the content library so a new story can be added
/// as pure data with confidence. Rejects: undecodable words, unresolved asset refs,
/// answers not among choices, fewer than 2 questions, and a beat count outside 2–3.
public struct StoryValidator {
    public let library: ContentLibrary

    public init(library: ContentLibrary = .standard) {
        self.library = library
    }

    public func validate(_ story: Story) -> [StoryDefect] {
        var defects: [StoryDefect] = []

        // Cast
        if story.cast.isEmpty { defects.append(.emptyCast) }
        for ref in story.cast where !library.hasPicture(ref) {
            defects.append(.missingPicture(ref: ref, context: "cast"))
        }

        // Beats: 2–3, unique ids, resolvable images
        if !(2...3).contains(story.beats.count) {
            defects.append(.beatCountOutOfRange(count: story.beats.count))
        }
        var seenBeatIDs = Set<String>()
        for beat in story.beats {
            if !seenBeatIDs.insert(beat.id).inserted {
                defects.append(.duplicateBeatID(id: beat.id))
            }
            if !library.hasPicture(beat.image) {
                defects.append(.missingPicture(ref: beat.image, context: "beat \(beat.id)"))
            }
        }
        let beatIDs = Set(story.beats.map(\.id))

        // Lines: non-empty, decodable-or-glue words, valid beat refs
        for (i, line) in story.lines.enumerated() {
            if line.words.isEmpty { defects.append(.emptyLine(lineIndex: i)) }
            if !beatIDs.contains(line.beat) {
                defects.append(.lineReferencesUnknownBeat(lineIndex: i, beat: line.beat))
            }
            for word in line.words where !library.isSpeakable(word.text, glue: word.glue) {
                defects.append(.undecodableWord(lineIndex: i, word: word.text))
            }
        }

        // Questions: ≥2, 2–4 unique resolvable choices, answer among choices
        if story.questionSets.count < 2 {
            defects.append(.tooFewQuestions(count: story.questionSets.count))
        }
        for (i, q) in story.questionSets.enumerated() {
            if q.choices.count < 2 { defects.append(.tooFewChoices(questionIndex: i, count: q.choices.count)) }
            if q.choices.count > 4 { defects.append(.tooManyChoices(questionIndex: i, count: q.choices.count)) }
            var seen = Set<String>()
            for ref in q.choices {
                if !seen.insert(ref).inserted { defects.append(.duplicateChoice(questionIndex: i, ref: ref)) }
                if !library.hasPicture(ref) {
                    defects.append(.missingPicture(ref: ref, context: "question \(i) choice"))
                }
            }
            if !q.choices.contains(q.answer) {
                defects.append(.answerNotInChoices(questionIndex: i, answer: q.answer))
            }
        }

        return defects
    }

    public func isValid(_ story: Story) -> Bool { validate(story).isEmpty }
}
