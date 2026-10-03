import XCTest
import SwiftUI
import FretNoteCore
@testable import FretNoteApp

final class LearningHistoryTests: XCTestCase {
    @MainActor
    func testLegacyMigrationAndIncrementalSessionPersistence() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("progress.json")
        var old = NoteProgress()
        old.record(correct: true, seconds: 2, hinted: false)
        try JSONEncoder().encode(["1:0": old]).write(to: file)
        let store = PracticeStore(file: file)
        XCTAssertTrue(store.sessions.isEmpty)
        XCTAssertEqual(store.progress["1:0"]?.attempts, 1)
        store.mode = .melody
        store.start()
        store.skip()
        // A force quit before ending a session must not lose completed answers.
        let saved = PracticeStore(file: file)
        XCTAssertEqual(saved.sessions.count, 1)
        XCTAssertEqual(saved.sessions.first?.answered, 1)
        XCTAssertEqual(saved.sessions.first?.skipped, 1)
        XCTAssertEqual(saved.sessions.first?.hints, 0)
        XCTAssertNil(saved.sessions.first?.endedAt)
        XCTAssertEqual(saved.progress["1:0"]?.attempts, 1)
        try await Task.sleep(nanoseconds: 170_000_000)
        store.reveal()
        store.receive(try XCTUnwrap(store.target).midi)
        store.end()
        store.end()
        let restored = PracticeStore(file: file)
        XCTAssertEqual(restored.sessions.count, 1)
        XCTAssertEqual(restored.sessions.first?.answered, 2)
        XCTAssertEqual(restored.sessions.first?.firstCorrect, 0)
        XCTAssertEqual(restored.sessions.first?.hints, 1)
        XCTAssertNotNil(restored.sessions.first?.endedAt)
        store.start(); store.end()
        XCTAssertEqual(store.sessions.count, 1, "Empty sessions should not clutter history")
        store.start(); store.skip(); store.end()
        XCTAssertEqual(PracticeStore(file: file).sessions.count, 2)
    }

    @MainActor
    func testCleanAnswerAndUnknownArchiveProtection() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("progress.json")
        let store = PracticeStore(file: file)
        store.start()
        try await Task.sleep(nanoseconds: 170_000_000)
        store.receive(try XCTUnwrap(store.target).midi)
        store.end()
        XCTAssertEqual(store.sessions.first?.firstCorrect, 1)
        XCTAssertEqual(store.sessions.first?.accuracy, "100%")
        let future = try JSONEncoder().encode(LearningArchive(version: 999, progress: [:], sessions: []))
        try future.write(to: file)
        let unknown = PracticeStore(file: file)
        XCTAssertNotNil(unknown.persistenceError)
        unknown.start(); unknown.skip(); unknown.end()
        XCTAssertEqual(try Data(contentsOf: file), future)
    }

    @MainActor
    func testRenderHistory() async throws {
        guard let path = ProcessInfo.processInfo.environment["FRETNOTE_HISTORY_SNAPSHOT_DIR"] else { return }
        _ = NSApplication.shared
        let folder = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("fixture-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: file) }
        var score = NoteProgress()
        for index in 0..<60 {
            score.record(correct: index % 20 < 17, seconds: 3, hinted: index % 20 >= 18)
        }
        let sessions = PracticeMode.allCases.map { mode in
            LearningSession(mode: mode.rawValue, scope: mode == .names ? "1 弦 · 0–21 品 · 自然音" : "六根弦 · 1–4 品 · 自然音", answered: 20, firstCorrect: 17, totalSeconds: 60, hints: 2, skipped: 1)
        }
        try JSONEncoder().encode(LearningArchive(progress: ["1:3": score], sessions: sessions)).write(to: file)
        let store = PracticeStore(file: file)
        for theme in [AppTheme.light, .dark] {
            let view = LearningHistoryView(practice: store).environment(\.interfaceScale, 1.75).preferredColorScheme(theme.colorScheme)
            let host = NSHostingView(rootView: view)
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 780, height: 640), styleMask: [.borderless], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: theme == .dark ? .darkAqua : .aqua)
            window.contentView = host
            window.orderFront(nil)
            try await Task.sleep(nanoseconds: 300_000_000)
            host.layoutSubtreeIfNeeded()
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: folder.appendingPathComponent("history-\(theme.rawValue).png"))
            window.orderOut(nil)
        }
    }
}
