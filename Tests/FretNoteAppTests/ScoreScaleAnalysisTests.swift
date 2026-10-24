import XCTest
import FretNoteCore
@testable import FretNoteApp

final class ScoreScaleAnalysisTests: XCTestCase {
    private func score(_ pitches: [Int]) -> GuitarProScore {
        var time = 0.0
        let frames: [GuitarProScore.Frame] = pitches.enumerated().map { index, midi in
            let string = (1...6).first { (0...21).contains(midi - GuitarNote(string: $0, fret: 0).midi) }!
            let duration = index == 0 || index == pitches.count - 1 ? 3.0 : 0.5
            defer { time += duration }
            return .init(start: time, end: time + duration, bar: index / 4 + 1,
                         notes: [.init(string: string, fret: midi - GuitarNote(string: string, fret: 0).midi, bend: [], tie: false, slide: false, legato: false)])
        }
        return .init(title: "Original tonal example", tempo: 120, barCount: (pitches.count + 3) / 4,
                     tracks: [.init(id: 0, name: "Lead", supported: true, frames: frames, events: [])])
    }
    func testMajorPhraseAndStableDegrees() throws {
        let result = ScoreScaleAnalyzer.analyze(score: score([60,64,67,65,62,69,71,60]), trackID: 0)
        let scale = try XCTUnwrap(result[1])
        XCTAssertEqual(scale.tonic, 0)
        XCTAssertEqual(scale.kind, .major)
        XCTAssertEqual(result[2], scale)
        XCTAssertEqual(scale.degree(midi: 64), "3")
        XCTAssertEqual(scale.degree(midi: 66), "♯4·")
    }
    func testMinorPentatonicAndBendTargetDegrees() throws {
        let result = ScoreScaleAnalyzer.analyze(score: score([64,67,69,71,74,71,67,64]), trackID: 0)
        let scale = try XCTUnwrap(result[1])
        XCTAssertEqual(scale.tonic, 4)
        XCTAssertEqual(scale.kind, .minorPentatonic)
        XCTAssertEqual(scale.degree(midi: 67), "♭3")
        XCTAssertEqual(scale.degree(midi: 74), "♭7")
        XCTAssertEqual(scale.degree(midi: 76), "1")
    }
    func testInsufficientNotesDoNotInventAScale() {
        XCTAssertTrue(ScoreScaleAnalyzer.analyze(score: score([64,64,67,64]), trackID: 0).isEmpty)
        XCTAssertTrue(ScoreScaleAnalyzer.analyze(score: score([]), trackID: 0).isEmpty)
    }
    func testOptionalLocalScoreAnalysis() throws {
        guard let path = ProcessInfo.processInfo.environment["FRETNOTE_GP_TEST"] else { throw XCTSkip("Optional private score") }
        let score = try GuitarProScore.load(URL(fileURLWithPath: path))
        let result = ScoreScaleAnalyzer.analyze(score: score, trackID: score.tracks.first(where: \.supported)!.id)
        print("Estimated scale phrases:", result.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value.tonicName) \($0.value.kind.rawValue)" }.joined(separator: ", "))
    }
}
