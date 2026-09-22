import Foundation
import FretNoteCore

struct LearningSession: Codable, Identifiable {
    var id = UUID()
    var startedAt = Date()
    var endedAt: Date?
    let mode: String
    let scope: String
    var answered = 0
    var firstCorrect = 0
    var totalSeconds = 0.0
    var hints = 0
    var skipped = 0
    var accuracy: String { answered == 0 ? "—" : "\(Int(Double(firstCorrect) / Double(answered) * 100))%" }
    var averageTime: String { answered == 0 ? "—" : String(format: "%.1f 秒", totalSeconds / Double(answered)) }
}

struct LearningArchive: Codable {
    var version = 1
    var progress: [String: NoteProgress]
    var sessions: [LearningSession]
}
