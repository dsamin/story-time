import XCTest
@testable import LearningKit

final class MasteryServiceTests: XCTestCase {

    func testHitPromotesMissDemotes() {
        let svc = MasteryService(intervals: [0, 10, 100, 1000])
        let t = MasteryService.Target(kind: .vocabulary, id: "cat")
        let now = Date(timeIntervalSince1970: 0)

        let r1 = svc.report(t, met: true, now: now)
        XCTAssertEqual(r1.box, 1)
        XCTAssertEqual(r1.met, 1)
        XCTAssertEqual(r1.dueAfter, now.addingTimeInterval(10))

        let r2 = svc.report(t, met: true, now: now)
        XCTAssertEqual(r2.box, 2)

        let r3 = svc.report(t, met: false, now: now)
        XCTAssertEqual(r3.box, 1)            // a miss demotes, never below 0
        XCTAssertEqual(r3.missed, 1)
    }

    func testDueOrdering() {
        let svc = MasteryService(intervals: [0, 10, 100])
        let now = Date(timeIntervalSince1970: 1000)
        let a = MasteryService.Target(kind: .vocabulary, id: "a")
        let b = MasteryService.Target(kind: .vocabulary, id: "b")
        svc.report(a, met: false, now: now)  // due immediately (box 0)
        svc.report(b, met: true, now: now)   // due in 10s
        XCTAssertEqual(svc.due(now: now), [a])
        XCTAssertEqual(Set(svc.due(now: now.addingTimeInterval(20))), [a, b])
    }

    func testStoriesDueIncludesUntouched() {
        let svc = MasteryService()
        let s1: Set = [MasteryService.Target(kind: .vocabulary, id: "cat")]
        let s2: Set = [MasteryService.Target(kind: .vocabulary, id: "dog")]
        // nothing reported yet → both stories are due
        XCTAssertEqual(svc.storiesDue(["s1": s1, "s2": s2]), ["s1", "s2"])
    }

    func testSnapshotRestoreRoundTrips() {
        let svc = MasteryService()
        let t = MasteryService.Target(kind: .comprehension, id: "x")
        svc.report(t, met: true)
        let snap = svc.snapshot()
        let svc2 = MasteryService()
        svc2.restore(snap)
        XCTAssertEqual(svc2.record(for: t), svc.record(for: t))
    }
}
