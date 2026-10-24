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
