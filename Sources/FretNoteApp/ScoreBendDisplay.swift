import Foundation
import FretNoteCore

struct ScoreBendDisplay: Equatable {
    let position: GuitarNote
    let semitones: Double
    let target: Double
    let releasing: Bool
    /// Visual string deflection in instrument coordinates, independent of camera zoom.
    /// Nut and bridge remain fixed; the finger pulls the string at the original fret.
    func stringDisplacement(at x: CGFloat) -> CGFloat {
        guard position.fret > 0, semitones.isFinite else { return 0 }
        let contact = GuitarGeometry.noteX(position.fret)
        let bridge = GuitarGeometry.scaleLength
        guard x > 0, x < bridge, contact > 0, contact < bridge else { return 0 }
        let envelope = x <= contact ? x / contact : (bridge - x) / (bridge - contact)
        // This view places the treble strings at the top: push inward, not off the neck.
        let direction: CGFloat = position.string <= 3 ? 1 : -1
        return direction * min(48, max(0, CGFloat(semitones)) * 16) * envelope
    }
    var progress: Double { min(1, max(0, semitones / max(0.01, target))) }
    var amountLabel: String {
        switch (target * 2).rounded() / 2 {
        case 0.5: return "¼"
        case 1: return "½"
        case 1.5: return "¾"
        case 2: return "full"
        case 3: return "1½"
        case 4: return "2"
        default: return String(format: "%g", target / 2)
        }
    }
    var pitchLabel: String {
        let midi = position.midi + Int(target.rounded(.down))
        let name = GuitarNote.names[midi % 12] + String(midi / 12 - 1)
        let cents = Int((target - target.rounded(.down)) * 100)
        return position.fullName + " → " + name + (cents == 0 ? "" : " +\(cents)¢")
    }

    /// Read the same per-note MIDI wheel and RPN range that drive the synth.
    /// The time is on the original score axis (before bar selection / slowdown).
    static func current(track: GuitarProScore.Track, frame: GuitarProScore.Frame, time: Double) -> [Self] {
        frame.notes.compactMap { note in
            let position = GuitarNote(string: note.string, fret: note.fret)
            var points = note.bend
            if points.isEmpty && note.tie {
                for previous in track.frames.reversed() where previous.start < frame.start {
                    guard let tied = previous.notes.first(where: { $0.string == note.string && $0.fret == note.fret }) else { break }
                    if !tied.bend.isEmpty { points = tied.bend; break }
                    if !tied.tie { break }
                }
            }
            guard !points.isEmpty else { return nil }
            let events = track.events.prefix { $0.time <= time }
            let channel = events.last { $0.kind == 1 && $0.key == position.midi }?.channel ?? 0
            var wheel = 8192, channelWheel = 8192, range = 2.0, cents = 0.0
            var rpnMSB = 127, rpnLSB = 127
            var releasing = false
            var hasWheel = false
            for event in events where event.channel == channel {
                if event.kind == 1 && event.key == position.midi { releasing = false }
                if event.kind == 3 {
                    if event.key == 101 { rpnMSB = event.value }
                    if event.key == 100 { rpnLSB = event.value }
                    if rpnMSB == 0 && rpnLSB == 0 {
                        if event.key == 6 { range = Double(event.value) }
                        if event.key == 38 { cents = Double(event.value) / 100 }
                    }
                } else if event.kind == 6 && event.key == position.midi {
                    if event.value != wheel { releasing = event.value < wheel }
                    wheel = event.value; hasWheel = true
                } else if event.kind == 5 { channelWheel = event.value }
            }
            let amount = hasWheel ? Double(wheel + channelWheel - 16384) / 8192 * (range + cents) : (points.first?.semitones ?? 0)
            let target = max(points.map(\.semitones).max() ?? 0, amount)
            guard target > 0.01 else { return nil }
            return Self(position: position, semitones: amount, target: target, releasing: releasing)
        }
    }
}
