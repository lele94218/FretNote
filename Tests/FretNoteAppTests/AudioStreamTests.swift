import XCTest
@testable import FretNoteApp

final class AudioStreamTests: XCTestCase {
    func testChunkedInterfaceAudioAtCommonSampleRates() {
        for rate in [44_100.0, 48_000.0, 96_000.0, 192_000.0] {
            for midi in [40, 67] {
                let analyzer = AudioAnalyzer(gate: 0.003)
                let frequency = 440 * pow(2, Double(midi - 69) / 12)
                let samples: [Float] = (0..<Int(rate * 0.5)).map { i in
                    Float(0.2 * sin(2 * Double.pi * frequency * Double(i) / rate))
                }
                var events: [Int] = []
                for offset in stride(from: 0, to: samples.count, by: 1024) {
                    analyzer.consume(Array(samples[offset..<min(offset + 1024, samples.count)]), rate: rate) { _, _, event in
                        if let event { events.append(event) }
                    }
                }
                XCTAssertEqual(events, [midi], "rate=\(rate), MIDI=\(midi)")
            }
        }
    }
}
