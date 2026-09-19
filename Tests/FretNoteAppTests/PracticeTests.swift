import XCTest
import SwiftUI
import FretNoteCore
@testable import FretNoteApp

final class PracticeTests: XCTestCase {
    @MainActor
    func testWrongThenCorrectAndPersistence() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("progress.json")
        let store = PracticeStore(file: file)
        store.start()
        try await Task.sleep(nanoseconds: 170_000_000)
        let target = try XCTUnwrap(store.target)
        store.receive(target.midi + 1)
        XCTAssertEqual(store.index, 0)
        store.receive(target.midi)
        XCTAssertTrue(store.completed)
        XCTAssertEqual(store.answered, 1)
        XCTAssertEqual(store.firstCorrect, 0)
        store.end()
        let restored = PracticeStore(file: file)
        XCTAssertEqual(restored.progress[target.id]?.attempts, 1)
        XCTAssertEqual(restored.progress[target.id]?.firstCorrect, 0)
    }
    @MainActor
    func testMelodyAdvancesOneNoteAndHintPreventsCleanCredit() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = PracticeStore(file: folder.appendingPathComponent("progress.json"))
        store.mode = .melody
        store.start()
        XCTAssertEqual(store.notes.count, 4)
        try await Task.sleep(nanoseconds: 170_000_000)
        store.reveal()
        store.receive(try XCTUnwrap(store.target).midi)
        XCTAssertEqual(store.index, 1)
        XCTAssertEqual(store.firstCorrect, 0)
        XCTAssertFalse(store.completed)
        store.skip()
        XCTAssertEqual(store.index, 2)
        store.end()
        let index = store.index
        store.receive(try XCTUnwrap(store.target).midi)
        XCTAssertEqual(store.index, index)
    }
    @MainActor
    func testCorruptProgressIsNotOverwritten() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("progress.json")
        let original = Data("invalid data".utf8)
        try original.write(to: file)
        let store = PracticeStore(file: file)
        XCTAssertNotNil(store.persistenceError)
        store.start(); store.skip(); store.end()
        XCTAssertEqual(try Data(contentsOf: file), original)
    }
    /// Optional offscreen UI render: FRETNOTE_SNAPSHOT_DIR=/tmp/... swift test --filter testRender
    @MainActor
    func testRender() async throws {
        guard let path = ProcessInfo.processInfo.environment["FRETNOTE_SNAPSHOT_DIR"] else { return }
        _ = NSApplication.shared
        let folder = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let audio = AudioInput()
        let store = PracticeStore(file: folder.appendingPathComponent("unused-progress.json"))
        for mode in PracticeMode.allCases {
            store.mode = mode
            store.notes = mode == .melody ? [GuitarNote(string: 3, fret: 0), GuitarNote(string: 3, fret: 2), GuitarNote(string: 2, fret: 0), GuitarNote(string: 3, fret: 2)] : [GuitarNote(string: 1, fret: 3)]
            let view = ContentView(audio: audio, practice: store).preferredColorScheme(.light).frame(width: 1160, height: 820)
            let host = NSHostingView(rootView: view)
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1160, height: 820), styleMask: [.borderless], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: .aqua)
            window.contentView = host
            window.orderFront(nil)
            try await Task.sleep(nanoseconds: 300_000_000)
            host.layoutSubtreeIfNeeded()
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            try data.write(to: folder.appendingPathComponent("\(mode.id).png"))
            window.orderOut(nil)
        }
    }
}
