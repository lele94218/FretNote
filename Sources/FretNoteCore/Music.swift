import Foundation

public struct GuitarNote: Codable, Hashable, Identifiable {
    public let string: Int
    public let fret: Int
    public var id: String { "\(string):\(fret)" }
    public static let openMIDI = [64, 59, 55, 50, 45, 40]
    public var midi: Int { Self.openMIDI[string - 1] + fret }
    public var name: String { Self.names[midi % 12] }
    public var fullName: String { "\(name)\(midi / 12 - 1)" }
    public var isNatural: Bool { [0, 2, 4, 5, 7, 9, 11].contains(midi % 12) }
    public var frequency: Double { 440 * pow(2, Double(midi - 69) / 12) }
    public static let names = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
    public init(string: Int, fret: Int) { self.string = string; self.fret = fret }

    // Guitar notation is written one octave above its sounding pitch.
    // Diatonic distance from written E4 (bottom line of the treble staff).
    public var staffStep: Int {
        let written = midi + 12
        let diatonic = [0, 0, 1, 1, 2, 3, 3, 4, 4, 5, 5, 6][written % 12]
        return (written / 12 - 1) * 7 + diatonic - (4 * 7 + 2)
    }
}

public enum PracticeMode: String, CaseIterable, Identifiable {
    case names = "音名找音", staff = "五线谱找音", melody = "短旋律"
    public var id: String { rawValue }
    public var symbol: String {
        switch self { case .names: return "guitars"; case .staff: return "music.note"; case .melody: return "music.note.list" }
    }
}

public struct NoteProgress: Codable {
    public var attempts = 0
    public var firstCorrect = 0
    public var totalSeconds = 0.0
    public var hints = 0
    public var streak = 0
    public var lastPracticed: Date?
    public var due = Date.distantPast
    public init() {}
    public var accuracy: Double { attempts == 0 ? 0 : Double(firstCorrect) / Double(attempts) }
    public func weight(at now: Date) -> Double {
        if attempts == 0 { return 3 }
        let overdue = due <= now ? 3.0 : 0.3
        return overdue + (1 - accuracy) * 4 + min(2, totalSeconds / Double(attempts) / 8)
    }
    public mutating func record(correct: Bool, seconds: Double, hinted: Bool, now: Date = Date()) {
        attempts += 1
        if correct && !hinted { firstCorrect += 1; streak += 1 } else { streak = 0 }
        if hinted { hints += 1 }
        totalSeconds += max(0, seconds)
        lastPracticed = now
        let intervals: [TimeInterval] = [60, 600, 86_400, 3 * 86_400, 7 * 86_400, 14 * 86_400]
        due = now.addingTimeInterval(intervals[min(streak, intervals.count - 1)])
    }
}

public enum ExerciseGenerator {
    public static func pool(string: Int?, lower: Int, upper: Int, naturalsOnly: Bool) -> [GuitarNote] {
        guard lower >= 0, upper >= lower, upper <= 24 else { return [] }
        return (1...6).filter { string == nil || $0 == string }.flatMap { s in
            (lower...upper).map { GuitarNote(string: s, fret: $0) }
        }.filter { !naturalsOnly || $0.isNatural }
    }
    public static func make(pool: [GuitarNote], count: Int, progress: [String: NoteProgress], excluding: String? = nil) -> [GuitarNote] {
        guard !pool.isEmpty, count > 0 else { return [] }
        var result: [GuitarNote] = []
        for _ in 0..<count {
            let previous = result.last
            var options = pool.filter { note in
                if let previous {
                    return note.midi != previous.midi && abs(note.midi - previous.midi) <= 5 && abs(note.string - previous.string) <= 1
                }
                return note.id != excluding
            }
            if options.isEmpty { options = pool }
            let weights = options.map { progress[$0.id]?.weight(at: Date()) ?? 3 }
            var draw = Double.random(in: 0..<weights.reduce(0, +))
            var chosen = options.last!
            for (note, weight) in zip(options, weights) {
                draw -= weight
                if draw < 0 { chosen = note; break }
            }
            result.append(chosen)
        }
        return result
    }
}
