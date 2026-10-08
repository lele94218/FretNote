import Foundation

public enum LearningQuality: String, CaseIterable, Identifiable {
    case major, minor, augmented, diminished, major7, dominant7, minor7
    public var id: String { rawValue }
    public var isShell: Bool { [.major7, .dominant7, .minor7].contains(self) }
    public var title: String {
        switch self {
        case .major: return "大三 Major"
        case .minor: return "小三 Minor"
        case .augmented: return "增三 Augmented"
        case .diminished: return "减三 Diminished"
        case .major7: return "大七 Maj7"
        case .dominant7: return "属七 7"
        case .minor7: return "小七 m7"
        }
    }
    public var suffix: String {
        switch self {
        case .major: return " Major"
        case .minor: return " Minor"
        case .augmented: return "aug"
        case .diminished: return "dim"
        case .major7: return "maj7"
        case .dominant7: return "7"
        case .minor7: return "m7"
        }
    }
    public var intervals: [Int] {
        switch self {
        case .major: return [0, 4, 7]
        case .minor: return [0, 3, 7]
        case .augmented: return [0, 4, 8]
        case .diminished: return [0, 3, 6]
        case .major7: return [0, 4, 11]
        case .dominant7: return [0, 4, 10]
        case .minor7: return [0, 3, 10]
        }
    }
    public var degrees: [String] {
        let third = intervals[1] == 3 ? "♭3" : "3"
        let last = isShell ? (intervals[2] == 11 ? "7" : "♭7") : (intervals[2] == 6 ? "♭5" : intervals[2] == 8 ? "♯5" : "5")
        return ["1", third, last]
    }
}

public struct LearningTone: Identifiable, Equatable {
    public let note: GuitarNote
    public let degree: String
    public let name: String
    public var id: String { note.id }
}

public struct LearningShape: Identifiable, Equatable {
    public let tones: [LearningTone]
    public var id: String { tones.map(\.id).joined(separator: ",") }
    public var root: GuitarNote { tones.first(where: { $0.degree == "1" })!.note }
    public var lower: Int { tones.map(\.note.fret).min()! }
    public var upper: Int { tones.map(\.note.fret).max()! }
}

public enum LearningShapes {
    public static let roots = ["C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B"]

    // Preserve diatonic chord spelling independently of sounding pitch.
    public static func names(root: Int, quality: LearningQuality) -> [String] {
        guard (0..<12).contains(root) else { return [] }
        let letters = Array("CDEFGAB")
        let naturals = [0, 2, 4, 5, 7, 9, 11]
        let rootLetter = letters.firstIndex(of: roots[root].first!)!
        return zip([0, 2, quality.isShell ? 6 : 4], quality.intervals).map { offset, interval in
            let index = (rootLetter + offset) % 7
            var alteration = (root + interval - naturals[index] + 12) % 12
            if alteration > 6 { alteration -= 12 }
            return String(letters[index]) + String(repeating: alteration >= 0 ? "♯" : "♭", count: abs(alteration))
        }
    }

    /// Chords use adjacent strings; arpeggios use a selected two- or three-string path.
    /// All results are complete sounding voicings, not independent pitch-class matches.
    public static func make(root: Int, quality: LearningQuality, arpeggio: Bool,
                            bassString: Int, inversion: Int = 0, path: Int = 0,
                            includeOpen: Bool = false) -> [LearningShape] {
        guard (0..<12).contains(root), (0...2).contains(inversion), (0...2).contains(path) else { return [] }
        guard arpeggio ? (2...6).contains(bassString) : (3...6).contains(bassString) else { return [] }
        guard !quality.isShell || inversion == 0 else { return [] }
        let roles = arpeggio ? [0, 1, 2] : Array(inversion..<3) + Array(0..<inversion)
        let strings: [Int]
        if arpeggio {
            strings = path == 0 ? [bassString, bassString, bassString - 1]
                : path == 1 ? [bassString, bassString - 1, bassString - 1]
                : [bassString, bassString - 1, bassString - 2]
        } else { strings = [bassString, bassString - 1, bassString - 2] }
        guard strings.allSatisfy({ (1...6).contains($0) }) else { return [] }
        let spelled = names(root: root, quality: quality)
        var results: [LearningShape] = []
        for rootMIDI in 0...127 where rootMIDI % 12 == root {
            let pitches = roles.map { role in rootMIDI + quality.intervals[role] + (!arpeggio && role < inversion ? 12 : 0) }
            let frets = zip(pitches, strings).map { $0 - GuitarNote.openMIDI[$1 - 1] }
            guard frets.allSatisfy({ (includeOpen ? 0 : 1)...21 ~= $0 }) else { continue }
            let tones = zip(roles.indices, roles).map { index, role in
                LearningTone(note: GuitarNote(string: strings[index], fret: frets[index]), degree: quality.degrees[role], name: spelled[role])
            }
            results.append(LearningShape(tones: tones))
        }
        return results.sorted { $0.lower < $1.lower }
    }
}
