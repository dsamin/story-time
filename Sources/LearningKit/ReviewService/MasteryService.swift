import Foundation

/// The small cross-app "what needs review" spaced-repetition service. Apps report
/// which vocabulary / comprehension targets a child met or missed; the service says
/// what is due for another pass. Pure logic + Codable so it persists on-device. No
/// app-specific imports — part of the shared chassis (the `MasteryService` the slate
/// seeds in app 1).
public final class MasteryService {

    public enum TargetKind: String, Codable, Sendable {
        case vocabulary      // a specific word / picture
        case comprehension   // a question target (who/what/where) for a story
    }

    public struct Target: Hashable, Codable, Sendable {
        public let kind: TargetKind
        public let id: String
        public init(kind: TargetKind, id: String) { self.kind = kind; self.id = id }
    }

    /// One target's running record. `box` is a Leitner level: a hit promotes (review
    /// later), a miss demotes (review soon). `dueAfter` is when it next needs a pass.
    public struct Record: Codable, Sendable, Equatable {
        public var target: Target
        public var seen: Int = 0
        public var met: Int = 0
        public var missed: Int = 0
        public var box: Int = 0
        public var lastSeen: Date = .distantPast
        public var dueAfter: Date = .distantPast
    }

    /// Spacing per Leitner box (seconds). Index 0 = due immediately.
    private let intervals: [TimeInterval]
    private(set) public var records: [Target: Record] = [:]

    public init(intervals: [TimeInterval] = [0, 60, 300, 1800, 86_400, 5 * 86_400]) {
        self.intervals = intervals
    }

    /// Report an interaction with a target. A miss never "fails" the child — it just
    /// resurfaces the target sooner.
    @discardableResult
    public func report(_ target: Target, met: Bool, now: Date = Date()) -> Record {
        var r = records[target] ?? Record(target: target)
        r.seen += 1
        r.lastSeen = now
        if met {
            r.met += 1
            r.box = min(r.box + 1, intervals.count - 1)
        } else {
            r.missed += 1
            r.box = max(r.box - 1, 0)
        }
        r.dueAfter = now.addingTimeInterval(intervals[r.box])
        records[target] = r
        return r
    }

    /// Targets due for another pass, soonest first.
    public func due(now: Date = Date()) -> [Target] {
        records.values
            .filter { $0.dueAfter <= now }
            .sorted { $0.dueAfter < $1.dueAfter }
            .map(\.target)
    }

    /// Of the given stories (id → its target set), those with any due target — so a
    /// story whose words are due can be re-surfaced. Untouched stories count as due.
    public func storiesDue(_ storyTargets: [String: Set<Target>], now: Date = Date()) -> [String] {
        let dueSet = Set(due(now: now))
        return storyTargets.compactMap { id, targets in
            let touched = targets.contains { records[$0] != nil }
            if !touched { return id }
            return targets.contains(where: dueSet.contains) ? id : nil
        }.sorted()
    }

    public func record(for target: Target) -> Record? { records[target] }

    // MARK: Codable persistence (on-device only)

    public func snapshot() -> [Record] { Array(records.values) }

    public func restore(_ snapshot: [Record]) {
        records = Dictionary(uniqueKeysWithValues: snapshot.map { ($0.target, $0) })
    }
}
