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
        let suite = "FretNote.snapshots.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let appearance = AppearancePreferences(defaults: defaults)
        let audio = AudioInput()
        let store = PracticeStore(file: folder.appendingPathComponent("unused-progress.json"))
        let scenes: [(String, PracticeMode, Int, Int, Bool)] = [
            ("音名找音", .names, 0, 5, false),
            ("五线谱找音", .staff, 0, 5, false),
            ("短旋律", .melody, 0, 5, false),
            ("把位提示", .melody, 2, 5, true),
            ("空弦提示", .melody, 0, 5, true),
            ("高把位提示", .melody, 12, 17, true)
        ]
        for width in [1040.0, 1600.0] {
        for (theme, scale) in [(AppTheme.light, 1.25), (.dark, 1.25), (.light, 1.75), (.dark, 1.75)] {
        appearance.theme = theme; appearance.setFontScale(scale)
        for (name, mode, lower, upper, hint) in scenes {
            store.mode = mode
            store.lowerFret = lower; store.upperFret = upper; store.hint = hint
            store.notes = mode == .melody ? [GuitarNote(string: 3, fret: lower), GuitarNote(string: 3, fret: lower + 2), GuitarNote(string: 2, fret: lower), GuitarNote(string: 3, fret: lower + 2)] : [GuitarNote(string: 1, fret: 3)]
            let view = ContentView(audio: audio, practice: store)
                .environmentObject(appearance)
                .environment(\.interfaceScale, scale)
                .preferredColorScheme(theme.colorScheme)
                .frame(width: width, height: 1000)
            let host = NSHostingView(rootView: view)
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: 1000), styleMask: [.borderless], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: theme == .dark ? .darkAqua : .aqua)
            window.contentView = host
            window.orderFront(nil)
            try await Task.sleep(nanoseconds: 300_000_000)
            host.layoutSubtreeIfNeeded()
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            try data.write(to: folder.appendingPathComponent("\(name)-\(theme.rawValue)-\(Int(scale * 100))-w\(Int(width)).png"))
            if ProcessInfo.processInfo.environment["FRETNOTE_CAPTURE_MENU"] == "1",
               name == "音名找音", theme == .dark, scale == 1.25, width == 1040 {
                func findPicker(_ view: NSView) -> NSPopUpButton? {
                    if let picker = view as? NSPopUpButton,
                       picker.itemTitles == (0...12).map({ "\($0)" }) { return picker }
                    return view.subviews.compactMap { findPicker($0) }.first
                }
                let picker = try XCTUnwrap(findPicker(host))
                let timer = Timer(timeInterval: 0.6, repeats: false) { _ in
                    for (index, menuWindow) in NSApp.windows.enumerated() where menuWindow != window && menuWindow.isVisible {
                        guard let content = menuWindow.contentView,
                              let bitmap = content.bitmapImageRepForCachingDisplay(in: content.bounds) else { continue }
                        content.cacheDisplay(in: content.bounds, to: bitmap)
                        if let data = bitmap.representation(using: .png, properties: [:]) {
                            try? data.write(to: folder.appendingPathComponent("native-menu-\(index).png"))
                        }
                    }
                    picker.menu?.cancelTrackingWithoutAnimation()
                }
                RunLoop.main.add(timer, forMode: .common)
                picker.performClick(nil)
                timer.invalidate()
            }
            window.orderOut(nil)
        }
        }
        }
    }
}
