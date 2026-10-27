import Foundation
import FretNoteCore

struct ScoreBendDisplay: Equatable {
    let position: GuitarNote
    let semitones: Double
    let target: Double
    let releasing: Bool
    var vibrato = false
    var isBend = true
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
        return direction * min(48, max(vibrato ? -48 : 0, CGFloat(semitones) * 16)) * envelope
    }
    var progress: Double { min(1, max(0, semitones / max(0.01, target))) }
    var amountLabel: String {
        switch (target * 2).rounded() / 2 {
        case 0.5: return "¼"
        case 1: return "½"
        case 1.5: return "¾"
        case 2: return "full"
        case 2.5: return "1¼"
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

    /// Interpolate between MIDI wheel samples for continuous visual motion.
    /// Audio still uses its original events; no delay or extra playback time is introduced.
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
            let vibrato = (note.vibrato ?? 0) > 0
            guard !points.isEmpty || vibrato else { return nil }
            let events = track.events.prefix { $0.time <= time }
            let channel = events.last { $0.kind == 1 && $0.key == position.midi }?.channel ?? 0
            var wheel = 8192, channelWheel = 8192, range = 2.0, cents = 0.0
            var rpnMSB = 127, rpnLSB = 127
            var releasing = false
            var hasWheel = false
            var lastWheelTime: Double?
            var noteStart = frame.start
            var lastChannelWheelTime: Double?
            for event in events where event.channel == channel {
                if event.kind == 1 && event.key == position.midi { releasing = false; noteStart = event.time }
                if event.kind == 3 {
                    if event.key == 101 { rpnMSB = event.value }
                    if event.key == 100 { rpnLSB = event.value }
                    if rpnMSB == 0 && rpnLSB == 0 {
                        if event.key == 6 { range = Double(event.value) }
                        if event.key == 38 { cents = Double(event.value) / 100 }
                    }
                } else if event.kind == 6 && event.key == position.midi {
                    if event.value != wheel { releasing = event.value < wheel }
                    wheel = event.value; hasWheel = true; lastWheelTime = event.time
                } else if event.kind == 5 { channelWheel = event.value; lastChannelWheelTime = event.time }
            }
            var visualWheel = Double(wheel)
            if hasWheel, let lastWheelTime {
                let start = max(lastWheelTime, noteStart)
                // Never interpolate toward a reset belonging to a later attack.
                for event in track.events.dropFirst(events.count) where event.channel == channel {
                    if (event.kind == 1 || event.kind == 2) && event.key == position.midi { break }
                    if event.kind == 6 && event.key == position.midi {
                        if event.time > start {
                            let fraction = min(1, max(0, (time - start) / (event.time - start)))
                            visualWheel += Double(event.value - wheel) * fraction
                            if time > start && event.value != wheel { releasing = event.value < wheel }
                        }
                        break
                    }
                }
            }
            var visualChannelWheel = Double(channelWheel)
            if let previous = lastChannelWheelTime {
                let start = max(previous, noteStart)
                for event in track.events.dropFirst(events.count) where event.channel == channel {
                    if (event.kind == 1 || event.kind == 2) && event.key == position.midi { break }
                    if event.kind == 5 {
                        if event.time > start {
                            visualChannelWheel += Double(event.value - channelWheel) * min(1, max(0, (time - start) / (event.time - start)))
                        }
                        break
                    }
                }
            }
            let amount = hasWheel || lastChannelWheelTime != nil
                ? (visualWheel + visualChannelWheel - 16384) / 8192 * (range + cents) : (points.first?.semitones ?? 0)
            let target = points.map(\.semitones).max() ?? (vibrato ? 0.5 : max(0, amount))
            guard target > 0.01 || vibrato else { return nil }
            return Self(position: position, semitones: amount, target: target, releasing: releasing, vibrato: vibrato, isBend: !points.isEmpty)
        }
    }
}
