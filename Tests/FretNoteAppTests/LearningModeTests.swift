import XCTest
import SwiftUI
import FretNoteCore
@testable import FretNoteApp

final class LearningModeTests: XCTestCase {
    @MainActor
    func testLearningStopsAudioAndCannotStartPracticeOrWriteRecords() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("progress.json")
        let practice = PracticeStore(file: file)
        let audio = AudioInput()
        audio.running = true // No real capture or permission request in this test.
        practice.start(); practice.skip()
        practice.setLearning(true, audio: audio)
        XCTAssertFalse(audio.running)
        XCTAssertTrue(audio.learningMode)
        XCTAssertFalse(practice.active)
        XCTAssertFalse(practice.showSummary)
        let saved = try Data(contentsOf: file)
        let learning = LearningStore()
        learning.move(1); learning.shell = true; learning.arpeggio = true
        practice.start(); practice.skip(); practice.receive(69)
        await audio.start() // Must return before requesting microphone access.
        XCTAssertFalse(audio.starting)
        XCTAssertFalse(audio.running)
        XCTAssertFalse(practice.active)
        XCTAssertEqual(try Data(contentsOf: file), saved)
        practice.setLearning(false, audio: audio)
        XCTAssertFalse(audio.running)
        XCTAssertFalse(practice.learning)
        XCTAssertFalse(audio.learningMode)
    }
    @MainActor
    func testSelectionChangesAndEmptyCombination() {
        let store = LearningStore()
        XCTAssertEqual(store.selected?.tones.map(\.note.fret), [5, 4, 2])
        store.move(100)
        XCTAssertEqual(store.position, store.shapes.count - 1)
        store.shell = true
        XCTAssertEqual(store.quality, .major7)
        XCTAssertEqual(store.position, 0)
        store.arpeggio = true; store.rootString = 2; store.path = 2
        XCTAssertNil(store.selected)
        store.path = 1
        XCTAssertNotNil(store.selected)
    }
    @MainActor
    func testRenderLearning() async throws {
        guard let path = ProcessInfo.processInfo.environment["FRETNOTE_LEARNING_SNAPSHOT_DIR"] else { return }
        _ = NSApplication.shared
        let folder = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let suite = "FretNote.learning-snapshots.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let appearance = AppearancePreferences(defaults: defaults)
        for (name, shell, arpeggio, theme) in [("chord", false, false, AppTheme.light), ("shell", true, false, .dark), ("arpeggio", false, true, .light)] {
            let store = LearningStore()
            store.shell = shell; store.arpeggio = arpeggio
            let view = LearningView(store: store, leave: {})
                .environmentObject(appearance).environment(\.interfaceScale, 1.75)
                .preferredColorScheme(theme.colorScheme).frame(width: 1040, height: 740)
            let host = NSHostingView(rootView: view)
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1040, height: 740), styleMask: [.borderless], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: theme == .dark ? .darkAqua : .aqua)
            window.contentView = host; window.orderFront(nil)
            try await Task.sleep(nanoseconds: 300_000_000)
            host.layoutSubtreeIfNeeded()
            XCTAssertLessThanOrEqual(host.fittingSize.height, 740)
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: folder.appendingPathComponent("\(name).png"))
            window.orderOut(nil)
        }
    }
}
