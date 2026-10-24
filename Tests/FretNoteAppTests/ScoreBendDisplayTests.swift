import XCTest
import SwiftUI
import FretNoteCore
@testable import FretNoteApp

final class ScoreBendDisplayTests: XCTestCase {
    private func track() -> GuitarProScore.Track {
        let note = GuitarProScore.Note(string: 1, fret: 5,
            bend: [.init(offset: 0, semitones: 0), .init(offset: 0.5, semitones: 2), .init(offset: 1, semitones: 0)],
            tie: false, slide: false, legato: false)
        let events: [GuitarProScore.MIDIEvent] = [
            .init(time: 0, kind: 3, channel: 1, key: 101, value: 0),
            .init(time: 0, kind: 3, channel: 1, key: 100, value: 0),
            .init(time: 0, kind: 3, channel: 1, key: 6, value: 16),
            .init(time: 0, kind: 6, channel: 1, key: 69, value: 8192),
            .init(time: 0, kind: 1, channel: 1, key: 69, value: 95),
            .init(time: 0.5, kind: 6, channel: 1, key: 69, value: 9216),
            .init(time: 0.75, kind: 6, channel: 1, key: 69, value: 8704),
            .init(time: 0.8, kind: 6, channel: 0, key: 69, value: 16000),
            .init(time: 1, kind: 6, channel: 1, key: 69, value: 8192)
        ]
        return .init(id: 0, name: "Bend", supported: true,
                     frames: [.init(start: 0, end: 1.2, bar: 1, notes: [note])], events: events)
    }
    func testFullBendAndReleaseFollowTheSoundingChannel() throws {
        let track = track(), frame = track.frames[0]
        let start = try XCTUnwrap(ScoreBendDisplay.current(track: track, frame: frame, time: 0).first)
        XCTAssertEqual(start.progress, 0)
        XCTAssertEqual(start.amountLabel, "full")
        XCTAssertEqual(start.pitchLabel, "A4 → B4")
        let peak = try XCTUnwrap(ScoreBendDisplay.current(track: track, frame: frame, time: 0.5).first)
        XCTAssertEqual(peak.semitones, 2)
        XCTAssertEqual(peak.progress, 1)
        XCTAssertFalse(peak.releasing)
        let release = try XCTUnwrap(ScoreBendDisplay.current(track: track, frame: frame, time: 0.8).first)
        XCTAssertEqual(release.semitones, 0.8, accuracy: 0.00001)
        XCTAssertEqual(release.progress, 0.4, accuracy: 0.00001)
        XCTAssertTrue(release.releasing)
        XCTAssertEqual(release.position, start.position)
        XCTAssertEqual(ScoreBendDisplay.current(track: track, frame: frame, time: 1).first?.progress, 0)
    }
    func testSlowPlaybackInterpolatesBetweenWheelSamples() throws {
        let track = track(), frame = track.frames[0]
        // At 25% speed, a 16 ms screen refresh advances only 4 ms in the score.
        let values = try (0...10).map { tick in
            try XCTUnwrap(ScoreBendDisplay.current(track: track, frame: frame, time: 0.2 + Double(tick) * 0.004).first).semitones
        }
        for index in 1..<values.count {
            XCTAssertEqual(values[index] - values[index - 1], 0.016, accuracy: 0.00001)
        }
        XCTAssertEqual(values[0], 0.8, accuracy: 0.00001)
    }
    func testDoesNotInterpolateIntoNextAttack() throws {
        let source = track()
        let events = Array(source.events.prefix(6)) + [
            GuitarProScore.MIDIEvent(time: 0.6, kind: 2, channel: 1, key: 69, value: 0),
            .init(time: 0.7, kind: 6, channel: 1, key: 69, value: 8192),
            .init(time: 0.7, kind: 1, channel: 1, key: 69, value: 95)
        ]
        let track = GuitarProScore.Track(id: 0, name: "Boundary", supported: true, frames: source.frames, events: events)
        XCTAssertEqual(try XCTUnwrap(ScoreBendDisplay.current(track: track, frame: track.frames[0], time: 0.55).first).semitones, 2)
    }
    func testVibratoMovesBothDirectionsWithoutInventingBendLabel() throws {
        var note = track().frames[0].notes[0]
        note = .init(string: note.string, fret: note.fret, bend: [], tie: false, slide: false, legato: false, vibrato: 1)
        let frame = GuitarProScore.Frame(start: 0, end: 1, bar: 1, notes: [note])
        let events: [GuitarProScore.MIDIEvent] = [
            .init(time: 0, kind: 1, channel: 1, key: 69, value: 95),
            .init(time: 0, kind: 6, channel: 1, key: 69, value: 8192),
            .init(time: 0.1, kind: 6, channel: 1, key: 69, value: 10240),
            .init(time: 0.2, kind: 6, channel: 1, key: 69, value: 6144),
            .init(time: 0.3, kind: 6, channel: 1, key: 69, value: 8192)
        ]
        let track = GuitarProScore.Track(id: 0, name: "Vibrato", supported: true, frames: [frame], events: events)
        let up = try XCTUnwrap(ScoreBendDisplay.current(track: track, frame: frame, time: 0.1).first)
        let down = try XCTUnwrap(ScoreBendDisplay.current(track: track, frame: frame, time: 0.2).first)
        XCTAssertTrue(up.vibrato)
        XCTAssertFalse(up.isBend)
        XCTAssertEqual(up.semitones, 0.5)
        XCTAssertEqual(down.semitones, -0.5)
        let x = GuitarGeometry.noteX(note.fret)
        XCTAssertGreaterThan(up.stringDisplacement(at: x), 0)
        XCTAssertLessThan(down.stringDisplacement(at: x), 0)
        XCTAssertEqual(down.stringDisplacement(at: 0), 0)
        XCTAssertEqual(down.stringDisplacement(at: GuitarGeometry.scaleLength), 0)
        let channelEvents = events.map { event in
            GuitarProScore.MIDIEvent(time: event.time, kind: event.kind == 6 ? 5 : event.kind, channel: event.channel, key: event.key, value: event.value)
        }
        let beatTrack = GuitarProScore.Track(id: 0, name: "Beat vibrato", supported: true, frames: [frame], events: channelEvents)
        XCTAssertEqual(try XCTUnwrap(ScoreBendDisplay.current(track: beatTrack, frame: frame, time: 0.05).first).semitones, 0.25, accuracy: 0.0001)
    }
    func testImportedNoteAndBeatVibrato() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "vibrato", withExtension: "gp", subdirectory: "Fixtures"))
        let score = try GuitarProScore.load(url)
        let track = try XCTUnwrap(score.tracks.first)
        XCTAssertEqual(track.frames[0].notes[0].vibrato, 1)
        XCTAssertTrue(track.frames.contains { $0.notes.contains { $0.vibrato == 2 } })
        let frame = track.frames[0]
        let values = (0..<50).compactMap { ScoreBendDisplay.current(track: track, frame: frame, time: Double($0) * 0.01).first?.semitones }
        XCTAssertGreaterThan((values.max() ?? 0) - (values.min() ?? 0), 0.05)
    }
    func testImportedBendAndVibratoAreCombinedInPlaybackEvents() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "vibrato", withExtension: "gp", subdirectory: "Fixtures"))
        let track = try XCTUnwrap(GuitarProScore.load(url).tracks.first)
        let frame = try XCTUnwrap(track.frames.first { $0.notes.contains { !$0.bend.isEmpty && ($0.vibrato ?? 0) > 0 } })
        let samples = (1..<100).compactMap { index in
            ScoreBendDisplay.current(track: track, frame: frame, time: frame.start + (frame.end-frame.start)*Double(index)/100).first
        }
        XCTAssertEqual(samples.count, 99)
        XCTAssertTrue(samples.allSatisfy { $0.vibrato && $0.isBend })
        XCTAssertTrue(samples.allSatisfy { abs($0.target-2) < 0.001 && $0.amountLabel == "full" })
        XCTAssertGreaterThan(samples.map(\.semitones).max() ?? 0, 2.05)
        XCTAssertLessThan(samples.map(\.semitones).min() ?? 100, 1.95)
        XCTAssertGreaterThan(samples.map(\.semitones).min() ?? 0, 1)
        // The same imported events drive the synth, not an independent visual sine wave.
        let plan = MIDIPlaybackPlan(track: track, firstBar: frame.bar, lastBar: frame.bar, speed: 0.5)
        let pcm = try ScoreMIDIRenderer.render(plan)
        XCTAssertGreaterThan(pcm.frameLength, 0)
        XCTAssertGreaterThan((0..<Int(pcm.frameLength)).map { abs(pcm.floatChannelData![0][$0]) }.max() ?? 0, 0.01)
    }
    func testStringDeflectionKeepsEndpointsFixedAndReturnsWithPitch() {
        let note = GuitarNote(string: 5, fret: 12)
        let peak = ScoreBendDisplay(position: note, semitones: 2, target: 2, releasing: false)
        let release = ScoreBendDisplay(position: note, semitones: 1, target: 2, releasing: true)
        let rest = ScoreBendDisplay(position: note, semitones: 0, target: 2, releasing: true)
        let x = GuitarGeometry.noteX(note.fret)
        XCTAssertEqual(peak.stringDisplacement(at: 0), 0)
        XCTAssertEqual(peak.stringDisplacement(at: GuitarGeometry.scaleLength), 0)
        XCTAssertLessThan(peak.stringDisplacement(at: x), release.stringDisplacement(at: x))
        XCTAssertLessThan(release.stringDisplacement(at: x), 0)
        XCTAssertEqual(rest.stringDisplacement(at: x), 0)
        let treble = ScoreBendDisplay(position: GuitarNote(string: 1, fret: 12), semitones: 2, target: 2, releasing: false)
        XCTAssertGreaterThan(treble.stringDisplacement(at: x), 0)
        XCTAssertGreaterThan(peak.stringDisplacement(at: x / 2), peak.stringDisplacement(at: x))
    }
    func testFractionalBendLabels() {
        let position = GuitarNote(string: 1, fret: 5)
        XCTAssertEqual(ScoreBendDisplay(position: position, semitones: 0, target: 1, releasing: false).amountLabel, "½")
        XCTAssertEqual(ScoreBendDisplay(position: position, semitones: 0, target: 0.5, releasing: false).pitchLabel, "A4 → A4 +50¢")
    }
    @MainActor
    func testRenderBend() throws {
        guard let output = ProcessInfo.processInfo.environment["FRETNOTE_BEND_SNAPSHOT"] else { return }
        let track = track()
        let bends = ScoreBendDisplay.current(track: track, frame: track.frames[0], time: 0.8)
        let view = GuitarInstrumentCanvas(camera: .fitting(track.frames[0].positions), notes: [], current: 0,
            dark: false, activePositions: track.frames[0].positions, bends: bends)
            .background(Color.white).frame(width: 960, height: 380)
        let renderer = ImageRenderer(content: view)
        let bitmap = NSBitmapImageRep(cgImage: try XCTUnwrap(renderer.cgImage))
        try XCTUnwrap(bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.75])).write(to: URL(fileURLWithPath: output))
    }
}
