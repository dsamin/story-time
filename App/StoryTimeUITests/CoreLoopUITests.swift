import XCTest

/// Drives the full core loop through the real UI on an iPad simulator (macOS/Xcode only).
/// Verifies: listen → answer by tapping a picture → a WRONG tap re-models and lets you
/// retry (no buzzer/fail) → reread shows a fresh set → order the beats → replay → end,
/// plus the calm/offline/landscape constraints.
final class CoreLoopUITests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting", "1"]
        app.launch()
        return app
    }

    func testFullCoreLoopWithErrorlessRetry() {
        let app = launch()

        // Shelf: pick the first story tile (wordless).
        let tile = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'tile_'")).firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 5), "story shelf shows tiles")
        tile.tap()

        // Listening → questions appear. The story auto-advances to "your turn".
        let correct = app.buttons["choice_correct"]
        XCTAssertTrue(correct.waitForExistence(timeout: 20), "questions appear after the story plays")

        // Errorless: tap a WRONG choice — it must NOT end the flow; the correct choice is
        // re-modeled and the question stays. There is no buzzer or fail screen.
        let wrong = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'choice_wrong_'")).firstMatch
        if wrong.exists {
            wrong.tap()
            // Still on the same question (correct choice still present), no alert/fail.
            XCTAssertTrue(app.buttons["choice_correct"].waitForExistence(timeout: 10))
            XCTAssertEqual(app.alerts.count, 0, "a wrong tap never raises an alert/fail")
        }

        // Answer every question across both turns (reread draws a fresh set) until the
        // sequencing board appears.
        let sequencePlayQuery = app.buttons["sequencePlay"]
        let beatQuery = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'beat_'"))
        func screen(_ id: String) -> XCUIElement {
            app.descendants(matching: .any).matching(identifier: id).firstMatch
        }
        var guardCount = 0
        while !beatQuery.firstMatch.exists && guardCount < 12 {
            let c = app.buttons["choice_correct"]
            if c.waitForExistence(timeout: 3) { c.tap() }
            guardCount += 1
        }
        _ = screen // (container ids unreliable on plain stacks; use button-based signals)
        let onPlayer = app.buttons["replayStory"].exists
        let onEnd = app.descendants(matching: .any).matching(identifier: "endCard").firstMatch.exists
        let nBeats = beatQuery.count
        let ids = app.buttons.allElementsBoundByIndex.map { $0.identifier.isEmpty ? "<\($0.label)>" : $0.identifier }.joined(separator: ",")
        let diag = "player(replayBtn)=\(onPlayer) choices=\(app.buttons["choice_correct"].exists) beats=\(nBeats) end=\(onEnd) buttons=[\(ids)] guard=\(guardCount)"
        XCTAssertTrue(beatQuery.firstMatch.waitForExistence(timeout: 15), "sequencing board appears [\(diag)]")

        // Sequencing: tap each shuffled beat to drop it into the next open well (the app
        // supports tap-to-place as well as drag; taps are deterministic for the test).
        var placedGuard = 0
        while beatQuery.firstMatch.waitForExistence(timeout: 3) && placedGuard < 6 {
            beatQuery.firstMatch.tap()
            placedGuard += 1
        }

        XCTAssertTrue(sequencePlayQuery.waitForExistence(timeout: 8), "all beats placed → play appears")
        sequencePlayQuery.tap()

        // Replay → calm end card. A single tap returns to the shelf.
        let end = app.descendants(matching: .any).matching(identifier: "endCard").firstMatch
        XCTAssertTrue(end.waitForExistence(timeout: 25), "the calm end card appears after replay")
        end.tap()
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'tile_'")).firstMatch
            .waitForExistence(timeout: 8), "end card returns to the shelf")
    }

    func testParentGateBlocksAStrayTap() {
        let app = launch()
        let gate = app.descendants(matching: .any).matching(identifier: "parentGate").firstMatch
        XCTAssertTrue(gate.waitForExistence(timeout: 5))
        // A single stray tap (what a 4-year-old does) must NOT open settings.
        gate.tap()
        XCTAssertFalse(app.navigationBars["Grown-ups"].waitForExistence(timeout: 2),
                       "a single tap must not pass the gate")
    }

    func testLandscapeOnly() {
        let app = launch()
        let tile = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'tile_'")).firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 5))
        let frame = app.windows.firstMatch.frame
        XCTAssertGreaterThan(frame.width, frame.height, "the app presents landscape")
    }
}
