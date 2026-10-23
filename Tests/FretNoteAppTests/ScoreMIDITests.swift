import XCTest
import AVFoundation
import FretNoteCore
@testable import FretNoteApp

final class ScoreMIDITests: XCTestCase {
    private func fixture() throws -> GuitarProScore.Track {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "timing", withExtension: "gp5", subdirectory: "Fixtures"))
        return try XCTUnwrap(GuitarProScore.load(url).tracks.first)
    }
    func testRenderedRhythmPitchAndReducedSpeed() throws {
        let track = try fixture()
        XCTAssertTrue(track.events.contains { $0.kind == 6 && $0.value > 8192 })
        XCTAssertEqual(track.events.map(\.time), track.events.map(\.time).sorted())
        for speed in [1.0, 0.5] {
            let plan = MIDIPlaybackPlan(track: track, firstBar: 1, lastBar: 2, speed: speed)
            let buffer = try ScoreMIDIRenderer.render(plan)
            XCTAssertEqual(Double(buffer.frameLength) / 44100, 8 / speed, accuracy: 0.0001)
            let samples = try XCTUnwrap(buffer.floatChannelData?[0])
            let noteWindow = Array(UnsafeBufferPointer(start: samples.advanced(by: 4410), count: 4096))
            let reading = try XCTUnwrap(PitchDetector.detect(noteWindow, sampleRate: 44100, gate: 0.0001))
            XCTAssertEqual(reading.midi, 69, "Slower playback must keep concert A unchanged")
            let restStart = Int(0.68 / speed * 44100)
            let quiet = (0..<1024).map { abs(samples[restStart + $0]) }.max()!
            XCTAssertLessThan(Double(quiet), reading.rms * 0.1, "Only a quiet sample release tail may remain in a rest")
            XCTAssertTrue((0..<Int(buffer.frameLength)).allSatisfy { samples[$0].isFinite && abs(samples[$0]) <= 1 })
        }
    }
    func testBarSelectionRetainsInstrumentAndBend() throws {
        let track = try fixture()
        let selected = MIDIPlaybackPlan(track: track, firstBar: 2, lastBar: 2, speed: 1)
        XCTAssertEqual(selected.duration, 4)
        XCTAssertTrue(selected.events.contains { $0.time == 0 && $0.kind == 4 })
        XCTAssertTrue(selected.events.contains { $0.kind == 6 && $0.value > 8192 })
        let buffer = try ScoreMIDIRenderer.render(selected)
        XCTAssertGreaterThan((0..<Int(buffer.frameLength)).map { abs(buffer.floatChannelData![0][$0]) }.max()!, 0.01)
    }
    func testSelectionChasesHeldNotesAcrossCut() throws {
        let base = try fixture()
        let events: [GuitarProScore.MIDIEvent] = [
            .init(time: 0, kind: 4, channel: 0, key: 0, value: 25),
            .init(time: 0, kind: 1, channel: 0, key: 69, value: 100),
            .init(time: 3, kind: 2, channel: 0, key: 69, value: 0)
        ]
        let track = GuitarProScore.Track(id: 0, name: "Held", supported: true,
            frames: [.init(start: 0, end: 2, bar: 1, notes: base.frames[0].notes),
                     .init(start: 2, end: 4, bar: 2, notes: base.frames[0].notes)], events: events)
        let plan = MIDIPlaybackPlan(track: track, firstBar: 2, lastBar: 2, speed: 1)
        XCTAssertEqual(plan.events.first { $0.kind == 1 }?.time, 0)
        XCTAssertEqual(plan.events.first { $0.kind == 2 }?.time, 1)
        XCTAssertEqual(plan.duration, 2)
    }
    func testLocalSoloRendersEndToEnd() throws {
        guard let path = ProcessInfo.processInfo.environment["FRETNOTE_GP_TEST"] else { throw XCTSkip("Optional private score") }
        let score = try GuitarProScore.load(URL(fileURLWithPath: path))
        let track = try XCTUnwrap(score.tracks.first)
        let plan = MIDIPlaybackPlan(track: track, firstBar: 1, lastBar: score.barCount, speed: 1)
        let buffer = try ScoreMIDIRenderer.render(plan)
        XCTAssertEqual(Double(buffer.frameLength) / 44100, plan.duration, accuracy: 0.0001)
        let data = buffer.floatChannelData![0]
        XCTAssertTrue((0..<Int(buffer.frameLength)).contains { abs(data[$0]) > 0.01 })
    }

    private func stallUI() { Thread.sleep(forTimeInterval: 0.12) }

    func testPitchBendChangesSoundingPitch() throws {
        let base = try fixture()
        let events: [GuitarProScore.MIDIEvent] = [
            .init(time: 0, kind: 4, channel: 0, key: 0, value: 80),
            .init(time: 0, kind: 1, channel: 0, key: 69, value: 100),
            .init(time: 0.5, kind: 6, channel: 0, key: 69, value: 16384),
            .init(time: 1, kind: 2, channel: 0, key: 69, value: 0)
        ]
        let track = GuitarProScore.Track(id: 0, name: "Bend", supported: true,
            frames: [.init(start: 0, end: 1.2, bar: 1, notes: base.frames[0].notes)], events: events)
        let buffer = try ScoreMIDIRenderer.render(MIDIPlaybackPlan(track: track, firstBar: 1, lastBar: 1, speed: 1))
        for (position, expected) in [(0.2, 69), (0.7, 71)] {
            let samples = Array(UnsafeBufferPointer(start: buffer.floatChannelData![0].advanced(by: Int(position * 44100)), count: 4096))
            XCTAssertEqual(try XCTUnwrap(PitchDetector.detect(samples, sampleRate: 44100, gate: 0.0001)).midi, expected)
        }
    }

    @MainActor
    func testAudioClockAndStopOnLocalDevice() async throws {
        guard ProcessInfo.processInfo.environment["FRETNOTE_MIDI_DEVICE_TEST"] == "1" else { throw XCTSkip("Local output device only") }
        let player = ScoreMIDIPlayer()
        player.volume = 0
        try await player.prepare(track: fixture(), first: 1, last: 2, speed: 1)
        try player.play(from: 0, looping: false)
        defer { player.stop() }
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertGreaterThan(player.position, 0.15)
        let before = player.position
        // Audio must progress even while UI work is stalled.
        stallUI()
        XCTAssertGreaterThan(player.position, before + 0.07)
        try player.play(from: 7.85, looping: false)
        try await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertTrue(player.finished)
        try player.play(from: 7.9, looping: true)
        try await Task.sleep(nanoseconds: 350_000_000)
        XCTAssertLessThan(player.position, 1)
        XCTAssertFalse(player.finished)
        try player.setLooping(false)
        player.stop()
    }
}
