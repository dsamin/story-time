import Foundation
import SwiftData
import LearningKit

/// On-device-only persistence (SwiftData). No accounts, no sync, no network. Holds the
/// adult's settings, which stories are active, and the per-child mastery snapshot.
@Model
final class ParentSettings {
    var voiceVolume: Double
    var reduceMotion: Bool
    /// Empty means "all stories active".
    var disabledStoryIDs: [String]
    /// Codable snapshot of the MasteryService (`[MasteryService.Record]`).
    var masterySnapshot: Data?

    init(voiceVolume: Double = 1.0,
         reduceMotion: Bool = false,
         disabledStoryIDs: [String] = [],
         masterySnapshot: Data? = nil) {
        self.voiceVolume = voiceVolume
        self.reduceMotion = reduceMotion
        self.disabledStoryIDs = disabledStoryIDs
        self.masterySnapshot = masterySnapshot
    }
}

extension ParentSettings {
    func loadMastery(into service: MasteryService) {
        guard let data = masterySnapshot,
              let records = try? JSONDecoder().decode([MasteryService.Record].self, from: data) else { return }
        service.restore(records)
    }

    func saveMastery(from service: MasteryService) {
        masterySnapshot = try? JSONEncoder().encode(service.snapshot())
    }
}
