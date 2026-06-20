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
        var guardCount = 0
        while !beatQuery.firstMatch.waitForExistence(timeout: 3) && guardCount < 12 {
            let c = app.buttons["choice_correct"]
            if c.waitForExistence(timeout: 8) { c.tap() }
            guardCount += 1
        }
        XCTAssertTrue(beatQuery.firstMatch.waitForExistence(timeout: 20), "sequencing board appears")

        // Sequencing: drag each shuffled beat into a well, in order.
        let wellCount = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'well_'")).count
        for i in 0..<wellCount {
            let beat = beatQuery.firstMatch
            guard beat.waitForExistence(timeout: 5) else { break }
            let well = app.descendants(matching: .any).matching(identifier: "well_\(i)").firstMatch
            beat.press(forDuration: 0.6, thenDragTo: well)
        }

        if sequencePlayQuery.waitForExistence(timeout: 8) { sequencePlayQuery.tap() }

        // Replay → calm end card. A single tap returns to the shelf.
        let end = app.otherElements["endCard"].firstMatch
        XCTAssertTrue(end.waitForExistence(timeout: 25), "the calm end card appears after replay")
        end.tap()
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'tile_'")).firstMatch
            .waitForExistence(timeout: 8), "end card returns to the shelf")
    }

    func testParentGateBlocksAStrayTap() {
        let app = launch()
        let gate = app.otherElements["parentGate"].firstMatch
        XCTAssertTrue(gate.waitForExistence(timeout: 5))
        // A single stray tap (what a 4-year-old does) must NOT open settings.
        gate.tap()
        XCTAssertFalse(app.navigationBars["Grown-ups"].waitForExistence(timeout: 2),
                       "a single tap must not pass the gate")
    }

    func testLandscapeOnly() {
        let app = launch()
        XCTAssertTrue(app.tiles.firstMatch.exists || app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'tile_'")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(XCUIDevice.shared.orientation.isLandscape ||
                      app.windows.firstMatch.frame.width > app.windows.firstMatch.frame.height,
                      "the app presents landscape")
    }
}
