import XCTest
import FretNoteCore
@testable import FretNoteApp

final class ComplexBendImportTests: XCTestCase {
    private func load(_ name: String = "complex-bends", ext: String = "gp5") throws -> GuitarProScore.Track {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Fixtures"))
        let score = try GuitarProScore.load(url)
        return try XCTUnwrap(score.tracks.first)
    }
    private func display(_ track: GuitarProScore.Track, _ time: Double, string: Int = 1) throws -> ScoreBendDisplay {
        let frame = try XCTUnwrap(track.frames.first { $0.start <= time && time < $0.end })
        return try XCTUnwrap(ScoreBendDisplay.current(track: track, frame: frame, time: time).first { $0.position.string == string })
    }
    func testHoldTimingAndIndependentDoubleBendsSurviveImport() throws {
        let track = try load()
        XCTAssertEqual(track.frames[0].notes[0].bend.map(\.offset), [0, 0.75, 1])
        XCTAssertEqual(try display(track, 0.5).semitones, 0, accuracy: 0.01)
        XCTAssertEqual(try display(track, 0.875).semitones, 1, accuracy: 0.02)
        // The other string releases independently while the first is still unbent.
        XCTAssertEqual(try display(track, 0.25, string: 2).semitones, 2, accuracy: 0.02)
        XCTAssertEqual(try display(track, 0.75, string: 2).semitones, 1, accuracy: 0.02)
        XCTAssertEqual(try display(track, 1.5).semitones, 2.5, accuracy: 0.02)
        XCTAssertEqual(try display(track, 1.75).semitones, 1.5, accuracy: 0.02)
        XCTAssertTrue(try display(track, 1.75).releasing)
        XCTAssertEqual(try display(track, 2.1).amountLabel, "1¼")
        XCTAssertEqual(try display(track, 2.1).semitones, 2.5, accuracy: 0.02)
        XCTAssertEqual(try display(track, 2.375).semitones, 1.75, accuracy: 0.02)
        // The tied segment does not create another pluck.
        XCTAssertFalse(track.events.contains { $0.kind == 1 && $0.time >= 1 && $0.time < 2 })
    }
    func testBendWithVibratoKeepsItsInitialHoldAndContinuesThroughTies() throws {
        let track = try load()
        let held = try (1...20).map { try display(track, 3 + Double($0) * 0.01).semitones }
        XCTAssertLessThan(held.max()!, 0.25)
        XCTAssertGreaterThan(held.min()!, -0.25)
        XCTAssertGreaterThan(held.max()! - held.min()!, 0.05)
        let tied = try (1...20).map { try display(track, 3.5 + Double($0) * 0.01).semitones }
        XCTAssertGreaterThan(tied.min()!, 0.75)
        XCTAssertLessThan(tied.max()!, 1.25)
        // Next bar: the same sustained note releases only in the second half.
        XCTAssertEqual(try display(track, 4.75).semitones, 1, accuracy: 0.02)
        XCTAssertEqual(try display(track, 5.5).semitones, 0.5, accuracy: 0.02)
    }
    func testNativeGPZeroMidpointAndEarlyDestination() throws {
        let track = try load(ext: "gp")
        XCTAssertEqual(try display(track, 0.5).semitones, 0, accuracy: 0.02)
        XCTAssertEqual(try display(track, 0.875).semitones, 1, accuracy: 0.02)
        let curve = track.frames[2].notes[0].bend
        XCTAssertEqual(curve.map(\.offset), [0, 0.5, 0.51])
        XCTAssertEqual(try display(track, 2.1).semitones, 0.4, accuracy: 0.02)
        XCTAssertEqual(try display(track, 2.4).semitones, 2, accuracy: 0.02)
    }
    func testMalformedBendTimingIsRejectedAndNextImportStillWorks() throws {
        XCTAssertThrowsError(try load("invalid-bend-timing")) { error in
            XCTAssertTrue(error.localizedDescription.contains("Invalid bend timing"))
        }
        XCTAssertEqual(try load().frames.count, 7)
    }
    func testPrebendAudioAndResetAfterReattackAtBothSpeeds() throws {
        let track = try load()
        for speed in [1.0, 0.5] {
            let plan = MIDIPlaybackPlan(track: track, firstBar: 2, lastBar: 2, speed: speed)
            let pcm = try ScoreMIDIRenderer.render(plan)
            XCTAssertEqual(Double(pcm.frameLength) / 44100, 2 / speed, accuracy: 0.001)
            for (time, expectedMIDI) in [(0.1, 71.5), (0.6, 69.0)] {
                let start = Int(time / speed * 44100)
                let samples = Array(UnsafeBufferPointer(start: pcm.floatChannelData![0].advanced(by: start), count: 4096))
                let pitch = try XCTUnwrap(PitchDetector.detect(samples, sampleRate: 44100, gate: 0.0001))
                let expectedFrequency = 440 * pow(2, (expectedMIDI - 69) / 12)
                XCTAssertEqual(pitch.frequency, expectedFrequency, accuracy: 5)
            }
        }
    }
}
