import XCTest
import FretNoteCore
@testable import FretNoteApp

final class ShapePracticeTests: XCTestCase {
    @MainActor func testArpeggioProgressHintsSkippingAndPersistence() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("progress.json")
        let records = PracticeStore(file: file)
        let drill = ShapePracticeStore()
        drill.start(catalog: LearningShapes.catalog(root: 9, quality: .major, arpeggio: true), arpeggio: true, name: "A Major", shell: false)
        let target = try XCTUnwrap(drill.question).shape.tones.map(\.note.midi)
        drill.receive(note: target[0], records: records)
        XCTAssertEqual(drill.noteIndex, 0, "Old ringing audio must not answer a new question")
        let now = Date()
        drill.observeLevel(0, gate: 0.003, now: now)
        drill.observeLevel(0, gate: 0.003, now: now.addingTimeInterval(0.2))
        drill.receive(note: target[0], records: records)
        drill.receive(note: target[2], records: records)
        XCTAssertEqual(drill.noteIndex, 1)
        drill.receive(note: target[1], records: records)
        XCTAssertTrue(records.sessions.isEmpty, "Two notes are not one completed question")
        drill.receive(note: target[2], records: records)
        drill.receive(note: target[2], records: records)
        XCTAssertEqual(records.sessions.first?.answered, 1)
        XCTAssertEqual(records.sessions.first?.firstCorrect, 0)
        XCTAssertTrue(records.progress.isEmpty, "Do not change single-note statistics")
        drill.next(); drill.reveal(); drill.skip(records: records)
        XCTAssertEqual(records.sessions.first?.answered, 2)
        XCTAssertEqual(records.sessions.first?.hints, 1)
        XCTAssertEqual(records.sessions.first?.skipped, 1)
        drill.end(records: records); drill.end(records: records)
        let restored = PracticeStore(file: file)
        XCTAssertEqual(restored.sessions.count, 1)
        XCTAssertEqual(restored.sessions[0].answered, 2)
        XCTAssertEqual(restored.sessions[0].shapeResults?.count, 2)
        XCTAssertEqual(restored.sessions[0].unit, "题")
    }
    @MainActor func testChordNeverAccumulatesSingleNotesAndRejectsOctave() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let records = PracticeStore(file: folder.appendingPathComponent("progress.json"))
        let drill = ShapePracticeStore()
        drill.start(catalog: LearningShapes.catalog(root: 9, quality: .major7, arpeggio: false), arpeggio: false, name: "Amaj7", shell: true)
        let target = try XCTUnwrap(drill.question).shape.tones.map(\.note.midi)
        let now = Date()
        drill.observeLevel(0, gate: 0.003, now: now)
        drill.observeLevel(0, gate: 0.003, now: now.addingTimeInterval(0.2))
        target.forEach { drill.receive(note: $0, records: records) }
        XCTAssertFalse(drill.completed)
        drill.receive(chord: target.map { $0 + 12 }, records: records)
        XCTAssertFalse(drill.completed)
        drill.receive(chord: target, records: records)
        XCTAssertTrue(drill.completed)
        XCTAssertEqual(records.sessions.first?.firstCorrect, 0)
        XCTAssertEqual(records.sessions.first?.mode, "和弦练习 · 137")
        let audio = AudioInput()
        drill.reset(records: records, audio: audio)
        XCTAssertFalse(drill.practicing)
        XCTAssertFalse(audio.running)
        XCTAssertTrue(audio.learningMode)
        XCTAssertNil(drill.question)
    }
}
