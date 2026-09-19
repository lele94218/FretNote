import XCTest
@testable import FretNoteCore

final class MusicTests: XCTestCase {
    func testGuitarOctaveTransposition() {
        let g = GuitarNote(string: 1, fret: 3)
        XCTAssertEqual(g.midi, 67)
        XCTAssertEqual(g.fullName, "G4")
        XCTAssertEqual(g.staffStep, 9) // Written G5, above the treble staff.
        XCTAssertEqual(GuitarNote(string: 6, fret: 0).staffStep, -7) // Written E3.
        XCTAssertEqual(GuitarNote(string: 4, fret: 2).staffStep, 0) // Written E4.
        XCTAssertEqual(GuitarNote(string: 2, fret: 8).midi, g.midi)
    }
    func testPoolAndMelodyStayInPosition() {
        let pool = ExerciseGenerator.pool(string: nil, lower: 2, upper: 5, naturalsOnly: true)
        XCTAssertFalse(pool.isEmpty)
        for _ in 0..<100 {
            let notes = ExerciseGenerator.make(pool: pool, count: 5, progress: [:])
            XCTAssertEqual(notes.count, 5)
            XCTAssertTrue(notes.allSatisfy { (2...5).contains($0.fret) && $0.isNatural })
            for (a, b) in zip(notes, notes.dropFirst()) {
                XCTAssertNotEqual(a.midi, b.midi)
                XCTAssertLessThanOrEqual(abs(a.midi - b.midi), 5)
                XCTAssertLessThanOrEqual(abs(a.string - b.string), 1)
            }
        }
    }
    func testConstrainedAndEmptyPools() {
        XCTAssertTrue(ExerciseGenerator.pool(string: 1, lower: 0, upper: 5, naturalsOnly: true).allSatisfy { $0.string == 1 })
        XCTAssertTrue(ExerciseGenerator.pool(string: nil, lower: 5, upper: 2, naturalsOnly: true).isEmpty)
        XCTAssertTrue(ExerciseGenerator.make(pool: [], count: 4, progress: [:]).isEmpty)
        let note = GuitarNote(string: 1, fret: 3)
        XCTAssertEqual(ExerciseGenerator.make(pool: [note], count: 3, progress: [:]), [note, note, note])
    }
    func testSpacedReviewAndPersistence() throws {
        let now = Date(timeIntervalSince1970: 1_000_000)
        var progress = NoteProgress()
        progress.record(correct: true, seconds: 2, hinted: false, now: now)
        XCTAssertEqual(progress.firstCorrect, 1)
        XCTAssertEqual(progress.due.timeIntervalSince(now), 600)
        progress.record(correct: true, seconds: 8, hinted: true, now: now)
        XCTAssertEqual(progress.firstCorrect, 1)
        XCTAssertEqual(progress.streak, 0)
        XCTAssertEqual(progress.hints, 1)
        XCTAssertEqual(progress.due.timeIntervalSince(now), 60)
        let decoded = try JSONDecoder().decode(NoteProgress.self, from: JSONEncoder().encode(progress))
        XCTAssertEqual(decoded.attempts, 2)
        XCTAssertEqual(decoded.totalSeconds, 10)
    }
}
