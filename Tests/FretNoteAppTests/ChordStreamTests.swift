import XCTest
@testable import FretNoteApp

final class ChordStreamTests: XCTestCase {
    private func run(rate: Double, duration: Double, voices: (Double) -> [Int]) -> [[Int]] {
        let analyzer = AudioAnalyzer(gate: 0.003, chordMode: true)
        var events: [[Int]] = []
        analyzer.onChord = { _, event in if let event { events.append(event) } }
        let samples: [Float] = (0..<Int(rate * duration)).map { index in
            let time = Double(index) / rate
            var value = 0.0
            for midi in voices(time) {
                let f = 440 * pow(2, Double(midi - 69) / 12)
                for h in 1...5 { value += 0.1 / Double(h) * sin(2 * .pi * f * Double(h) * time) }
            }
            return Float(value)
        }
        for offset in stride(from: 0, to: samples.count, by: 1024) {
            analyzer.consume(Array(samples[offset..<min(offset + 1024, samples.count)]), rate: rate) { _, _, note in
                XCTAssertNil(note, "Chord analysis must not emit single-note answers")
            }
        }
        return events
    }
    func testSimultaneousAndStrummedWithReleaseAtInterfaceRates() {
        for rate in [44100.0, 48000, 96000] {
            let events = run(rate: rate, duration: 3.5) { time in
                if time < 1.5 { return [45,49,52] }
                if time < 2 { return [] }
                if time < 2.05 { return [45] }
                if time < 2.1 { return [45,49] }
                return [45,49,52]
            }
            XCTAssertEqual(events, [[45,49,52], [45,49,52]], "\(rate)")
        }
    }
    func testSeparatedNotesNeverPassEvenWhenTheyShareFFTWindow() {
        for duration in [0.12, 0.25, 0.6] {
            let events = run(rate: 48000, duration: duration * 3 + 0.5) { time in
                if time < duration { return [45] }
                if time < duration * 2 { return [49] }
                if time < duration * 3 { return [52] }
                return []
            }
            XCTAssertTrue(events.isEmpty, "Separate \(duration)s notes are not a chord: \(events)")
        }
    }
}
