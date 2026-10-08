import XCTest
@testable import FretNoteCore

final class LearningShapesTests: XCTestCase {
    func testChordCatalogAcrossRootsAndQualities() throws {
        for root in 0..<12 {
            for quality in LearningQuality.allCases {
                for string in 3...6 {
                    for inversion in 0..<(quality.isShell ? 1 : 3) {
                        let shapes = LearningShapes.make(root: root, quality: quality, arpeggio: false, bassString: string, inversion: inversion)
                        XCTAssertFalse(shapes.isEmpty)
                        for shape in shapes {
                            let pitches = shape.tones.map(\.note.midi)
                            XCTAssertEqual(shape.tones.map(\.note.string), [string, string - 1, string - 2])
                            XCTAssertEqual(pitches, pitches.sorted())
                            XCTAssertLessThan(pitches[2] - pitches[0], 12)
                            XCTAssertEqual((pitches[0] - root + 120) % 12, quality.intervals[inversion])
                            XCTAssertEqual(Set(pitches.map { ($0 - root + 120) % 12 }), Set(quality.intervals))
                            XCTAssertTrue(shape.tones.allSatisfy { (1...21).contains($0.note.fret) })
                        }
                    }
                }
            }
        }
    }
    func testReferenceVoicingsAndSpelling() {
        func frets(_ q: LearningQuality, _ s: Int, _ inversion: Int = 0) -> [[Int]] {
            LearningShapes.make(root: 9, quality: q, arpeggio: false, bassString: s, inversion: inversion).map { $0.tones.map(\.note.fret) }
        }
        XCTAssertTrue(frets(.major, 4, 1).contains([11, 9, 10]))
        XCTAssertTrue(frets(.diminished, 6).contains([5, 3, 1]))
        XCTAssertTrue(frets(.major7, 5).contains([12, 11, 13]))
        XCTAssertTrue(frets(.dominant7, 5).contains([12, 11, 12]))
        XCTAssertEqual(LearningShapes.names(root: 9, quality: .augmented), ["A", "C♯", "E♯"])
        XCTAssertEqual(LearningShapes.names(root: 6, quality: .augmented), ["F♯", "A♯", "C♯♯"])
        XCTAssertEqual(LearningShapes.names(root: 9, quality: .diminished), ["A", "C", "E♭"])
    }
    func testArpeggioPathsAndBounds() {
        for root in 0..<12 {
            for q in LearningQuality.allCases {
                for string in 2...6 {
                    for path in 0...2 {
                        let shapes = LearningShapes.make(root: root, quality: q, arpeggio: true, bassString: string, path: path)
                        if string == 2 && path == 2 { XCTAssertTrue(shapes.isEmpty); continue }
                        XCTAssertFalse(shapes.isEmpty)
                        for shape in shapes {
                            let pitches = shape.tones.map(\.note.midi)
                            XCTAssertEqual(pitches.map { $0 - pitches[0] }, q.intervals)
                            XCTAssertTrue(shape.tones.allSatisfy { (1...21).contains($0.note.fret) })
                        }
                    }
                }
            }
        }
        for (path, expected) in [(0, [5, 9, 7]), (1, [5, 4, 7]), (2, [5, 4, 2])] {
            let shapes = LearningShapes.make(root: 9, quality: .major, arpeggio: true, bassString: 6, path: path)
            XCTAssertTrue(shapes.contains { $0.tones.map(\.note.fret) == expected })
        }
        let open = LearningShapes.make(root: 9, quality: .major, arpeggio: false, bassString: 3, includeOpen: true)
        XCTAssertTrue(open.contains { $0.tones.map(\.note.fret) == [2, 2, 0] })
        XCTAssertTrue(LearningShapes.make(root: 9, quality: .major7, arpeggio: false, bassString: 5, inversion: 1).isEmpty)
    }
}
