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
        learning.position = 1; learning.quality = .major7; learning.arpeggio = true
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
    func testCatalogCoversGroupsAndPathsWithoutSelectors() {
        let store = LearningStore()
        XCTAssertGreaterThan(store.catalog.count, 12)
        XCTAssertEqual(Set(store.catalog.map(\.label)), ["654 弦", "543 弦", "432 弦", "321 弦"])
        store.position = 2
        store.quality = .major7
        XCTAssertEqual(store.position, 0)
        XCTAssertTrue(store.catalog.allSatisfy { $0.shape.tones.map(\.degree) == ["1", "3", "7"] })
        store.arpeggio = true
        XCTAssertEqual(Set(store.catalog.map(\.label)), ["前两音同弦", "后两音同弦", "每弦一个音"])

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
        for (suffix, width, height, fontScale) in [("", 1160.0, 820.0, 1.25), ("-large-text", 1040.0, 740.0, 1.75)] {
        for (name, shell, arpeggio, theme) in [("chord", false, false, AppTheme.light), ("shell", true, false, .dark), ("arpeggio", false, true, .light)] {
            for exercise in [false, true] {
            let store = LearningStore()
            store.quality = shell ? .major7 : .major; store.arpeggio = arpeggio
            let practice = PracticeStore(file: folder.appendingPathComponent("progress.json"))
            let audio = AudioInput()
            practice.setLearning(true, audio: audio)
            let drill = ShapePracticeStore()
            if exercise {
                drill.start(catalog: Array(store.catalog.prefix(1)), arpeggio: arpeggio, name: "A", shell: shell)
            }
            let view = LearningView(store: store, practice: practice, audio: audio, drill: drill)
                .environmentObject(appearance).environment(\.interfaceScale, fontScale)
                .preferredColorScheme(theme.colorScheme).frame(width: width, height: height)
            let host = NSHostingView(rootView: view)
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height), styleMask: [.borderless], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: theme == .dark ? .darkAqua : .aqua)
            window.contentView = host; window.orderFront(nil)
            try await Task.sleep(nanoseconds: 300_000_000)
            host.layoutSubtreeIfNeeded()
            XCTAssertLessThanOrEqual(host.fittingSize.height, height)
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: folder.appendingPathComponent("\(name)\(exercise ? "-exercise" : "")\(suffix).png"))
            window.orderOut(nil)
            }
        }
        }
    }
}
