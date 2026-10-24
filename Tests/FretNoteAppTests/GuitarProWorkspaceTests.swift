import XCTest
@testable import FretNoteApp

final class GuitarProWorkspaceTests: XCTestCase {
    @MainActor
    func testRestoresOpenDocumentsAndSelectedTabWithoutOriginalFiles() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("workspace.json")
        let store = GuitarProWorkspace(file: file)
        let score = GuitarProScore(title: "Original test", tempo: 120, barCount: 1, tracks: [
            .init(id: 0, name: "Guitar", supported: true,
                  frames: [.init(start: 0, end: 1, bar: 1, notes: [])],
                  events: [.init(time: 0, kind: 4, channel: 0, key: 27, value: 0)])
        ])
        try store.add(score: score, sourceName: "one.gp5")
        let first = try XCTUnwrap(store.selectedID)
        try store.add(score: score, sourceName: "two.gp5")
        store.select(first)
        let restored = GuitarProWorkspace(file: file)
        XCTAssertEqual(restored.documents.map(\.sourceName), ["one.gp5", "two.gp5"])
        XCTAssertEqual(restored.selectedID, first)
        XCTAssertEqual(restored.selected?.score.tracks.first?.events.first?.key, 27)
        restored.close(first)
        let closed = GuitarProWorkspace(file: file)
        XCTAssertEqual(closed.documents.count, 1)
        XCTAssertEqual(closed.selected?.sourceName, "two.gp5")
        closed.close(try XCTUnwrap(closed.selectedID))
        XCTAssertTrue(GuitarProWorkspace(file: file).documents.isEmpty)
    }
    @MainActor
    func testFailedSaveDoesNotPretendTheImportWasSaved() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        try Data("occupied".utf8).write(to: file)
        let store = GuitarProWorkspace(file: file.appendingPathComponent("workspace.json"))
        XCTAssertThrowsError(try store.add(score: .init(title: "Test", tempo: 120, barCount: 0, tracks: []), sourceName: "test.gp"))
        XCTAssertTrue(store.documents.isEmpty)
    }
}
