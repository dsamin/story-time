import XCTest
@testable import StoryTimeCore
import LearningKit

final class StoryValidatorTests: XCTestCase {
    let validator = StoryValidator()

    // A known-good base story we can mutate to provoke specific defects.
    func makeValidStory() -> Story {
        Story(
            id: "t", title: "T", cast: ["cat", "dog"],
            lines: [
                Line(words: [Word(text: "The", glue: true), Word(text: "cat", glue: false), Word(text: "sat", glue: false)], beat: "b1"),
                Line(words: [Word(text: "The", glue: true), Word(text: "dog", glue: false), Word(text: "ran", glue: false)], beat: "b2"),
            ],
            beats: [
                Beat(id: "b1", image: "mat", caption: "the cat sat"),
                Beat(id: "b2", image: "dog", caption: "the dog ran"),
            ],
            questionSets: [
                Question(prompt: "Who sat?", type: .who, choices: ["cat", "dog"], answer: "cat", expansion: "the cat sat!"),
                Question(prompt: "Who ran?", type: .who, choices: ["dog", "cat"], answer: "dog", expansion: "the dog ran!"),
            ]
        )
    }

    func testValidStoryHasNoDefects() {
        XCTAssertEqual(validator.validate(makeValidStory()), [])
        XCTAssertTrue(validator.isValid(makeValidStory()))
    }

    func testRejectsUndecodableWord() {
        var s = makeValidStory()
        s = Story(id: s.id, title: s.title, cast: s.cast,
                  lines: [Line(words: [Word(text: "elephant", glue: false)], beat: "b1")] + Array(s.lines.dropFirst()),
                  beats: s.beats, questionSets: s.questionSets)
        XCTAssertTrue(validator.validate(s).contains(.undecodableWord(lineIndex: 0, word: "elephant")))
    }

    func testGlueWordMarkedDecodableIsRejected() {
        // "the" is glue; if authored as non-glue it is not in the decodable inventory.
        let s = Story(id: "t", title: "T", cast: ["cat"],
                      lines: [Line(words: [Word(text: "the", glue: false), Word(text: "cat", glue: false)], beat: "b1")],
                      beats: [Beat(id: "b1", image: "mat", caption: "c"), Beat(id: "b2", image: "dog", caption: "d")],
                      questionSets: [
                        Question(prompt: "?", type: .who, choices: ["cat", "dog"], answer: "cat", expansion: "x"),
                        Question(prompt: "?", type: .who, choices: ["cat", "dog"], answer: "dog", expansion: "x"),
                      ])
        XCTAssertTrue(validator.validate(s).contains(.undecodableWord(lineIndex: 0, word: "the")))
    }

    func testRejectsMissingAssets() {
        let s = Story(id: "t", title: "T", cast: ["unicorn"],
                      lines: [Line(words: [Word(text: "cat", glue: false)], beat: "b1")],
                      beats: [Beat(id: "b1", image: "nope", caption: "c"), Beat(id: "b2", image: "dog", caption: "d")],
                      questionSets: [
                        Question(prompt: "?", type: .who, choices: ["cat", "ghost"], answer: "cat", expansion: "x"),
                        Question(prompt: "?", type: .who, choices: ["cat", "dog"], answer: "dog", expansion: "x"),
                      ])
        let defects = validator.validate(s)
        XCTAssertTrue(defects.contains(.missingPicture(ref: "unicorn", context: "cast")))
        XCTAssertTrue(defects.contains(.missingPicture(ref: "nope", context: "beat b1")))
        XCTAssertTrue(defects.contains(.missingPicture(ref: "ghost", context: "question 0 choice")))
    }

    func testRejectsAnswerNotInChoices() {
        var base = makeValidStory()
        base = Story(id: base.id, title: base.title, cast: base.cast, lines: base.lines, beats: base.beats,
                     questionSets: [
                        Question(prompt: "?", type: .who, choices: ["cat", "dog"], answer: "pig", expansion: "x"),
                        base.questionSets[1],
                     ])
        XCTAssertTrue(validator.validate(base).contains(.answerNotInChoices(questionIndex: 0, answer: "pig")))
    }

    func testRejectsFewerThanTwoQuestions() {
        var base = makeValidStory()
        base = Story(id: base.id, title: base.title, cast: base.cast, lines: base.lines, beats: base.beats,
                     questionSets: [base.questionSets[0]])
        XCTAssertTrue(validator.validate(base).contains(.tooFewQuestions(count: 1)))
    }

    func testRejectsBeatCountOutOfRange() {
        var base = makeValidStory()
        // one beat (too few) — also fix line refs to that beat
        base = Story(id: base.id, title: base.title, cast: base.cast,
                     lines: [Line(words: [Word(text: "cat", glue: false)], beat: "b1")],
                     beats: [Beat(id: "b1", image: "mat", caption: "c")],
                     questionSets: base.questionSets)
        XCTAssertTrue(validator.validate(base).contains(.beatCountOutOfRange(count: 1)))
    }

    func testRejectsTooManyChoices() {
        var base = makeValidStory()
        base = Story(id: base.id, title: base.title, cast: base.cast, lines: base.lines, beats: base.beats,
                     questionSets: [
                        Question(prompt: "?", type: .who, choices: ["cat", "dog", "pig", "hen", "fox"], answer: "cat", expansion: "x"),
                        base.questionSets[1],
                     ])
        XCTAssertTrue(validator.validate(base).contains(.tooManyChoices(questionIndex: 0, count: 5)))
    }

    func testRejectsLineWithUnknownBeat() {
        var base = makeValidStory()
        base = Story(id: base.id, title: base.title, cast: base.cast,
                     lines: [Line(words: [Word(text: "cat", glue: false)], beat: "nope")] + Array(base.lines.dropFirst()),
                     beats: base.beats, questionSets: base.questionSets)
        XCTAssertTrue(validator.validate(base).contains(.lineReferencesUnknownBeat(lineIndex: 0, beat: "nope")))
    }
}
