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
    @MainActor
    func testFourFretPositionAndCustomRange() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = PracticeStore(file: folder.appendingPathComponent("progress.json"))
        XCTAssertEqual(store.lowerFret, 1)
        XCTAssertEqual(store.upperFret, 4)
        for lower in 1...18 {
            store.lowerFret = lower
            XCTAssertEqual(store.upperFret, lower + 3)
            store.mode = .melody
            store.start()
            XCTAssertTrue(store.notes.allSatisfy { (lower...(lower + 3)).contains($0.fret) })
            store.end()
        }
        store.customRange = true
        store.lowerFret = 21
        store.upperFret = 24
        XCTAssertEqual(store.upperFret, 21)
        store.naturalsOnly = false
        store.start()
        XCTAssertFalse(store.notes.isEmpty)
        XCTAssertTrue(store.notes.allSatisfy { $0.fret == 21 })
        store.end()
        store.customRange = false
        XCTAssertEqual(store.lowerFret, 18)
        XCTAssertEqual(store.upperFret, 21)
        store.customRange = true
        store.lowerFret = 0
        store.upperFret = 5
        XCTAssertEqual(store.upperFret, 5)
        store.lowerFret = 8
        XCTAssertEqual(store.upperFret, 8)
        store.upperFret = 10
        XCTAssertEqual(store.upperFret, 10)
        store.customRange = false
        XCTAssertEqual(store.upperFret, 11)
        store.customRange = true
        store.lowerFret = 0
        store.customRange = false
        XCTAssertEqual(store.lowerFret, 1)
        XCTAssertEqual(store.upperFret, 4)
    }

    @MainActor
    func testNamesUseWholeStringAndAcceptEitherOctave() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = PracticeStore(file: folder.appendingPathComponent("progress.json"))
        store.string = 1
        store.lowerFret = 18
        store.naturalsOnly = false
        XCTAssertEqual(store.exercisePool.map(\.fret), Array(0...21))
        XCTAssertTrue(store.exercisePool.allSatisfy { $0.string == 1 })
        store.start()
        store.notes = [GuitarNote(string: 1, fret: 3)]
        try await Task.sleep(nanoseconds: 170_000_000)
        store.receive(43) // G below this string's range must not pass.
        XCTAssertEqual(store.index, 0)
        store.receive(GuitarNote(string: 1, fret: 15).midi)
        XCTAssertEqual(store.answered, 1)
        XCTAssertNotNil(store.progress["1:15"])
        XCTAssertNil(store.progress["1:3"])
        store.end()
        store.mode = .staff
        XCTAssertEqual(store.exercisePool.map(\.fret), Array(18...21))
        store.start()
        store.notes = [GuitarNote(string: 1, fret: 3)]
        try await Task.sleep(nanoseconds: 170_000_000)
        store.receive(GuitarNote(string: 1, fret: 15).midi)
        XCTAssertEqual(store.index, 0) // Staff mode still requires the written octave.
        store.end()
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
        for (width, height) in [(1040.0, 740.0), (1160.0, 820.0), (1600.0, 900.0)] {
        for (theme, scale) in [(AppTheme.light, 1.25), (.dark, 1.25), (.light, 1.75), (.dark, 1.75)] {
        appearance.theme = theme; appearance.setFontScale(scale)
        for (name, mode, lower, upper, hint) in scenes {
            audio.running = hint
            store.active = hint
            store.feedback = hint ? "请弹奏目标音。" : "等待开始。"
            store.mode = mode
            store.customRange = true
            store.lowerFret = lower; store.upperFret = upper; store.hint = hint
            store.notes = mode == .melody ? [GuitarNote(string: 3, fret: lower), GuitarNote(string: 3, fret: lower + 2), GuitarNote(string: 2, fret: lower), GuitarNote(string: 3, fret: lower + 2)] : [GuitarNote(string: 1, fret: 3)]
            let view = ContentView(audio: audio, practice: store)
                .environmentObject(appearance)
                .environment(\.interfaceScale, scale)
                .preferredColorScheme(theme.colorScheme)
                .frame(width: width, height: height)
            let host = NSHostingView(rootView: view)
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height), styleMask: [.borderless], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: theme == .dark ? .darkAqua : .aqua)
            window.contentView = host
            window.orderFront(nil)
            try await Task.sleep(nanoseconds: 300_000_000)
            host.layoutSubtreeIfNeeded()
            func checkNoScrolling(_ view: NSView) {
                if let scroll = view as? NSScrollView, let document = scroll.documentView {
                    XCTAssertLessThanOrEqual(document.frame.height, scroll.contentView.bounds.height + 1,
                                             "Content must fit without vertical scrolling at \(width)×\(height), \(scale)")
                }
                view.subviews.forEach(checkNoScrolling)
            }
            checkNoScrolling(host)
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
            if name == "把位提示", width == 1040 {
                store.index = 3
                try await Task.sleep(nanoseconds: 300_000_000)
                host.layoutSubtreeIfNeeded()
                let followed = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                host.cacheDisplay(in: host.bounds, to: followed)
                try XCTUnwrap(followed.representation(using: .png, properties: [:])).write(to: folder.appendingPathComponent("跟随末音-\(theme.rawValue)-\(Int(scale * 100)).png"))
                store.index = 0
            }
            window.orderOut(nil)
        }
        audio.running = false
        store.active = false
        for tab in [0, 1] {
        let settings = AppSettingsView(audio: audio, initialTab: tab)
            .environmentObject(appearance)
            .environment(\.interfaceScale, scale)
            .preferredColorScheme(theme.colorScheme)
        let settingsHost = NSHostingView(rootView: settings)
        settingsHost.frame = NSRect(x: 0, y: 0, width: 620, height: 580)
        let settingsWindow = NSWindow(contentRect: settingsHost.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        settingsWindow.appearance = NSAppearance(named: theme == .dark ? .darkAqua : .aqua)
        settingsWindow.contentView = settingsHost
        settingsWindow.orderFront(nil)
        try await Task.sleep(nanoseconds: 200_000_000)
        settingsHost.layoutSubtreeIfNeeded()
        let settingsBitmap = try XCTUnwrap(settingsHost.bitmapImageRepForCachingDisplay(in: settingsHost.bounds))
        settingsHost.cacheDisplay(in: settingsHost.bounds, to: settingsBitmap)
        try XCTUnwrap(settingsBitmap.representation(using: .png, properties: [:])).write(to: folder.appendingPathComponent("设置-\(tab)-\(theme.rawValue)-\(Int(scale * 100)).png"))
        settingsWindow.orderOut(nil)
        }
        }
        }
    }
}
