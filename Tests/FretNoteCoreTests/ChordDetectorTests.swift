import XCTest
@testable import FretNoteCore

final class ChordDetectorTests: XCTestCase {
    static func signal(_ midis: [Int], amplitudes: [Double] = [], harmonics: Int = 6, cents: Double = 0, count: Int = 4096, offset: Int = 0) -> [Float] {
        (0..<count).map { index in
            let time = Double(index + offset) / 12000
            var sum = 0.0
            for (j, midi) in midis.enumerated() {
                let frequency = 440 * pow(2, (Double(midi) - 69 + cents / 100) / 12)
                for h in 1...harmonics {
                    sum += (amplitudes.isEmpty ? 0.12 : amplitudes[j]) / Double(h) * sin(2 * .pi * frequency * Double(h) * time + Double(j) * 0.7)
                }
            }
            return Float(sum)
        }
    }
    func testClosedVoicingsAcrossQualitiesRootsAndOctaves() {
        let detector = ChordDetector()
        for root in Array(40...63) + [69] {
            for quality in LearningQuality.allCases {
                for inversion in 0..<(quality.isShell ? 1 : 3) {
                    let roles = Array(inversion..<3) + Array(0..<inversion)
                    let midis = roles.map { root + quality.intervals[$0] + ($0 < inversion ? 12 : 0) }
                    let result = detector.detect(Self.signal(midis), sampleRate: 12000)
                    XCTAssertEqual(result?.midis, midis, "\(quality) \(midis)")
                }
            }
        }
    }
    func testDynamicsTuningMissingWrongOctaveAndExtraNotes() {
        let detector = ChordDetector()
        for cents in [-20.0, 0, 20] {
            for amplitudes in [[0.12, 0.07, 0.2], [0.2, 0.06, 0.1]] {
                XCTAssertEqual(detector.detect(Self.signal([45, 49, 52], amplitudes: amplitudes, cents: cents), sampleRate: 12000)?.midis, [45,49,52])
            }
        }
        for notes in [[45], [45,49], [45,48,52], [45,49,64], [45,49,52,55]] {
            XCTAssertNotEqual(detector.detect(Self.signal(notes), sampleRate: 12000)?.midis, [45,49,52])
        }
        XCTAssertNil(detector.detect([Float](repeating: 0, count: 4096), sampleRate: 12000))
        var seed: UInt64 = 42
        let noise: [Float] = (0..<4096).map { _ in
            seed = seed &* 6364136223846793005 &+ 1
            return Float(Double(seed >> 33) / Double(UInt32.max) - 0.25)
        }
        XCTAssertNil(detector.detect(noise, sampleRate: 12000))
    }
    func testGateRequiresStableSimultaneousNotesAndRelease() {
        var gate = ChordGate()
        let chord = ChordReading(midis: [45,49,52], confidence: 1)
        XCTAssertNil(gate.process(chord, rms: 0.1, now: 0, gate: 0.003))
        XCTAssertNil(gate.process(chord, rms: 0.1, now: 0.34, gate: 0.003))
        XCTAssertEqual(gate.process(chord, rms: 0.1, now: 0.46, gate: 0.003), [45,49,52])
        XCTAssertNil(gate.process(chord, rms: 0.1, now: 3, gate: 0.003))
        _ = gate.process(nil, rms: 0, now: 3.1, gate: 0.003)
        _ = gate.process(nil, rms: 0, now: 3.3, gate: 0.003)
        XCTAssertNil(gate.process(chord, rms: 0.1, now: 3.4, gate: 0.003))
        XCTAssertEqual(gate.process(chord, rms: 0.1, now: 3.9, gate: 0.003), [45,49,52])
    }
}
