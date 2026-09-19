import XCTest
@testable import FretNoteCore

final class PitchTests: XCTestCase {
    private let rate = 12_000.0
    private func signal(midi: Int, harmonics: Bool = false, cents: Double = 0) -> [Float] {
        let frequency = 440 * pow(2, (Double(midi - 69) + cents / 100) / 12)
        return (0..<1536).map { i in
            let phase = 2 * Double.pi * frequency * Double(i) / rate
            let envelope = exp(-Double(i) / rate * 3)
            let fundamental = (harmonics ? 0.3 : 1.0) * sin(phase)
            let overtone = harmonics ? 0.6 * sin(2 * phase) + 0.2 * sin(3 * phase) : 0
            return Float(0.3 * envelope * (fundamental + overtone))
        }
    }
    func testEveryGuitarPitchIncludingDominantSecondHarmonic() throws {
        for midi in 40...88 {
            for harmonics in [false, true] {
                let reading = try XCTUnwrap(PitchDetector.detect(signal(midi: midi, harmonics: harmonics), sampleRate: rate), "MIDI \(midi)")
                XCTAssertEqual(reading.midi, midi, "harmonics=\(harmonics)")
                XCTAssertLessThan(abs(reading.cents), 15)
            }
        }
    }
    func testSilenceAndDeterministicNoiseAreNotNotes() {
        XCTAssertNil(PitchDetector.detect([Float](repeating: 0, count: 1536), sampleRate: rate))
        var seed: UInt64 = 99
        let noise: [Float] = (0..<1536).map { _ in
            seed = 6364136223846793005 &* seed &+ 1
            return Float(Double(seed >> 33) / Double(UInt32.max) - 0.25)
        }
        XCTAssertNil(PitchDetector.detect(noise, sampleRate: rate))
    }
    func testCentsAndGate() throws {
        let samples = signal(midi: 64, cents: 22)
        let pitch = try XCTUnwrap(PitchDetector.detect(samples, sampleRate: rate))
        XCTAssertEqual(pitch.midi, 64)
        XCTAssertEqual(pitch.cents, 22, accuracy: 3)
        XCTAssertNil(PitchDetector.detect(samples.map { $0 * 0.001 }, sampleRate: rate))
    }
    func testSustainOnlyEmitsOnceAndSilenceRearms() {
        var gate = NoteGate()
        let reading = PitchReading(frequency: 440, confidence: 0.99, rms: 0.1)
        var events: [Int] = []
        for i in 0..<30 {
            if let event = gate.process(reading, rms: 0.1, now: Double(i) * 0.032, gate: 0.003) { events.append(event) }
        }
        XCTAssertEqual(events, [69])
        for i in 30..<35 { XCTAssertNil(gate.process(nil, rms: 0, now: Double(i) * 0.032, gate: 0.003)) }
        for i in 35..<45 {
            if let event = gate.process(reading, rms: 0.1, now: Double(i) * 0.032, gate: 0.003) { events.append(event) }
        }
        XCTAssertEqual(events, [69, 69])
    }
    func testBriefWrongPitchAndOutOfTuneDoNotEmit() {
        var gate = NoteGate()
        let bad = PitchReading(frequency: 440 * pow(2, 0.49 / 12), confidence: 0.99, rms: 0.1)
        for i in 0..<20 { XCTAssertNil(gate.process(bad, rms: 0.1, now: Double(i) * 0.032, gate: 0.003)) }
        let a = PitchReading(frequency: 440, confidence: 0.99, rms: 0.1)
        let b = PitchReading(frequency: 493.883, confidence: 0.99, rms: 0.1)
        for i in 20..<40 { XCTAssertNil(gate.process(i % 2 == 0 ? a : b, rms: 0.1, now: Double(i) * 0.032, gate: 0.003)) }
    }
    func testLegatoPitchChangeAndFreshAttack() {
        var gate = NoteGate()
        var events: [Int] = []
        for i in 0..<45 {
            let midi = i < 15 ? 69 : 71
            let amplitude = i < 30 ? 0.03 : 0.2
            let reading = PitchReading(frequency: 440 * pow(2, Double(midi - 69) / 12), confidence: 0.99, rms: amplitude)
            if let event = gate.process(reading, rms: amplitude, now: Double(i) * 0.032, gate: 0.003) { events.append(event) }
        }
        XCTAssertEqual(events, [69, 71, 71])
    }
}
