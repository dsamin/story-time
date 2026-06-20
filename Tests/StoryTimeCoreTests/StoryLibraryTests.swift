import XCTest
@testable import StoryTimeCore
import LearningKit

final class StoryLibraryTests: XCTestCase {

    func testAtLeastFiveStoriesLoad() throws {
        let stories = try StoryLibrary.loadAll()
        XCTAssertGreaterThanOrEqual(stories.count, 5, "the slate ships ≥5 micro-stories")
    }

    func testEveryAuthoredStoryPassesValidation() throws {
        let validator = StoryValidator()
        let stories = try StoryLibrary.loadAll()
        for story in stories {
            let defects = validator.validate(story)
            XCTAssertEqual(defects, [], "story \(story.id) defects: \(defects.map(\.description))")
        }
    }

    func testEachStoryHasTwoTurnsAndBeats() throws {
        for story in try StoryLibrary.loadAll() {
            XCTAssertTrue((2...3).contains(story.beats.count), "\(story.id) beats")
            let t0 = story.questions(forTurn: 0)
            let t1 = story.questions(forTurn: 1)
            XCTAssertFalse(t0.isEmpty, "\(story.id) turn 0")
            XCTAssertFalse(t1.isEmpty, "\(story.id) turn 1")
            // reread must be a genuinely fresh set
            let prompts0 = Set(t0.map(\.prompt))
            let prompts1 = Set(t1.map(\.prompt))
            XCTAssertTrue(prompts0.isDisjoint(with: prompts1), "\(story.id) reread set must differ")
        }
    }

    func testTitlesExistButCastDrivesShelf() throws {
        for story in try StoryLibrary.loadAll() {
            XCTAssertFalse(story.title.isEmpty)        // adult-facing only
            XCTAssertFalse(story.cast.isEmpty)         // cast drives the wordless tile
        }
    }
}
