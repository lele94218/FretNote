import Foundation
import FretNoteCore

struct ScoreScaleEstimate: Equatable, Sendable {
    enum Kind: String, Sendable {
        case major = "大调", minor = "自然小调", minorPentatonic = "小调五声音阶", majorPentatonic = "大调五声音阶"
        case blues = "小调布鲁斯音阶", harmonicMinor = "和声小调", dorian = "多利亚调式", mixolydian = "混合利底亚调式", lydian = "利底亚调式", phrygian = "弗里几亚调式"
        var intervals: [Int] {
            switch self {
            case .major: return [0,2,4,5,7,9,11]
            case .minor: return [0,2,3,5,7,8,10]
            case .minorPentatonic: return [0,3,5,7,10]
            case .majorPentatonic: return [0,2,4,7,9]
            case .blues: return [0,3,5,6,7,10]
            case .harmonicMinor: return [0,2,3,5,7,8,11]
            case .dorian: return [0,2,3,5,7,9,10]
            case .mixolydian: return [0,2,4,5,7,9,10]
            case .lydian: return [0,2,4,6,7,9,11]
            case .phrygian: return [0,1,3,5,7,8,10]
            }
        }
    }
    let tonic: Int
    let kind: Kind
    var tonicName: String { ["C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B"][tonic] }
    func degree(midi: Int) -> String {
        let interval = ((midi - tonic) % 12 + 12) % 12
        let names = ["1", "♭2", "2", "♭3", "3", "4", kind == .blues ? "♭5" : "♯4", "5", "♭6", "6", "♭7", "7"]
        return names[interval] + (kind.intervals.contains(interval) ? "" : "·")
    }
}

/// Duration-weighted key profiles establish a tonal centre, then four-bar phrases
/// are matched against scale pitch sets. Results are estimates, not harmonic proof.
/// Profile reference: https://music21.org/music21docs/moduleReference/moduleAnalysisDiscrete.html
/// Implemented locally; no music21 dependency or network access.
enum ScoreScaleAnalyzer {
    private static let major = [6.35,2.23,3.48,2.33,4.38,4.09,2.52,5.19,2.39,3.66,2.29,2.88]
    private static let minor = [6.33,2.68,3.52,5.38,2.60,3.53,2.54,4.75,3.98,2.69,3.34,3.17]

    static func analyze(score: GuitarProScore, trackID: Int) -> [Int: ScoreScaleEstimate] {
        guard score.barCount > 0, let track = score.tracks.first(where: { $0.id == trackID }) else { return [:] }
        let melody = histogram(frames: track.frames)
        guard melody.filter({ $0 > 0 }).count >= 3 else { return [:] }
        var global = normalized(melody)
        let others = score.tracks.filter { $0.id != trackID }
        for other in others {
            let harmony = normalized(midiHistogram(track: other))
            for pc in 0..<12 { global[pc] += harmony[pc] * 0.35 / Double(max(1, others.count)) }
        }
        let ending = track.frames.last(where: { !$0.notes.isEmpty })?.positions.first?.midi
        var key = (root: 0, isMinor: false, value: -Double.infinity)
        for root in 0..<12 {
            for isMinor in [false, true] {
                let profile = isMinor ? minor : major
                let rotated = (0..<12).map { profile[($0 - root + 12) % 12] }
                let value = correlation(global, rotated) + (ending.map { $0 % 12 == root ? 0.12 : 0 } ?? 0)
                if value > key.value { key = (root, isMinor, value) }
            }
        }
        var result: [Int: ScoreScaleEstimate] = [:]
        for first in stride(from: 1, through: max(1, score.barCount), by: 4) {
            let phrase = histogram(frames: track.frames.filter { $0.bar >= first && $0.bar < first + 4 })
            let observed = normalized(phrase)
            guard observed.filter({ $0 > 0.005 }).count >= 3 else { continue }
            let base: ScoreScaleEstimate.Kind = key.isMinor ? .minor : .major
            let candidates: [ScoreScaleEstimate.Kind] = key.isMinor ? [.minor, .harmonicMinor, .dorian, .phrygian] : [.major, .mixolydian, .lydian]
            func coverage(_ kind: ScoreScaleEstimate.Kind) -> Double {
                kind.intervals.reduce(0) { $0 + observed[(key.root + $1) % 12] }
            }
            // Preserve the key's default mode unless characteristic tones give clear evidence.
            var kind = candidates.max { a, b in
                coverage(a) + (a == base ? 0.035 : 0) < coverage(b) + (b == base ? 0.035 : 0)
            } ?? base
            let pent: ScoreScaleEstimate.Kind = key.isMinor ? .minorPentatonic : .majorPentatonic
            let distinct = pent.intervals.filter { observed[(key.root + $0) % 12] > 0.01 }.count
            if coverage(pent) >= 0.97 && distinct >= 4 { kind = pent }
            else if key.isMinor && coverage(.blues) >= 0.97 && observed[(key.root + 6) % 12] > 0.015 && distinct >= 4 { kind = .blues }
            guard coverage(kind) >= 0.8 else { continue }
            let estimate = ScoreScaleEstimate(tonic: key.root, kind: kind)
            for bar in first...min(score.barCount, first + 3) { result[bar] = estimate }
        }
        return result
    }

    private static func histogram(frames: [GuitarProScore.Frame]) -> [Double] {
        var values = Array(repeating: 0.0, count: 12)
        for frame in frames {
            let duration = max(0, frame.end - frame.start) / Double(max(1, frame.notes.count))
            for note in frame.notes {
                let midi = GuitarNote(string: note.string, fret: note.fret).midi
                // Keep both the fretted source and sustained bend target in the evidence.
                let bend = note.bend.map(\.semitones).max() ?? 0
                let raised = bend >= 0.75 ? Int(bend.rounded()) : 0
                values[midi % 12] += duration * (raised > 0 ? 0.4 : 1)
                if raised > 0 { values[(midi + raised) % 12] += duration * 0.6 }
            }
        }
        return values
    }
    private static func midiHistogram(track: GuitarProScore.Track) -> [Double] {
        var values = Array(repeating: 0.0, count: 12)
        var held: [Int: GuitarProScore.MIDIEvent] = [:]
        func end(_ on: GuitarProScore.MIDIEvent, at time: Double) {
            values[on.key % 12] += min(8, max(0, time - on.time))
        }
        for event in track.events where event.channel != 9 {
            let id = event.channel * 128 + event.key
            if event.kind == 1 && event.value > 0 {
                if let previous = held[id] { end(previous, at: event.time) }
                held[id] = event
            } else if event.kind == 2 || (event.kind == 1 && event.value == 0) {
                if let on = held.removeValue(forKey: id) { end(on, at: event.time) }
            }
        }
        for on in held.values { end(on, at: track.frames.last?.end ?? on.time) }
        return values
    }
    private static func normalized(_ values: [Double]) -> [Double] {
        let total = values.reduce(0, +)
        return total > 0 ? values.map { $0 / total } : values
    }
    private static func correlation(_ a: [Double], _ b: [Double]) -> Double {
        let ma = a.reduce(0, +) / 12, mb = b.reduce(0, +) / 12
        let numerator = zip(a, b).reduce(0) { $0 + ($1.0 - ma) * ($1.1 - mb) }
        let denominator = sqrt(a.reduce(0) { $0 + pow($1 - ma, 2) } * b.reduce(0) { $0 + pow($1 - mb, 2) })
        return denominator > 0 ? numerator / denominator : 0
    }
}
