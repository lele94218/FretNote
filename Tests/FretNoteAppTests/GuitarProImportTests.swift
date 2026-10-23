import XCTest
import SwiftUI
@testable import FretNoteApp

final class GuitarProImportTests: XCTestCase {
    func testRhythmRepeatsRestsAndTempoInGP5AndGP7() throws {
        for ext in ["gp5", "gp"] {
            let url = try XCTUnwrap(Bundle.module.url(forResource: "timing", withExtension: ext, subdirectory: "Fixtures"))
            let score = try GuitarProScore.load(url)
            let track = try XCTUnwrap(score.tracks.first)
            let frames = track.frames
            XCTAssertTrue(track.supported)
            XCTAssertEqual(frames.map(\.bar), [1,1,1,1,1,1,1,1,2])
            XCTAssertEqual(frames.map(\.start), [0,0.5,0.75,1,2,2.5,2.75,3,4])
            XCTAssertEqual(frames.last!.end, 8, accuracy: 0.001)
            XCTAssertTrue(frames[1].notes.isEmpty)
            XCTAssertEqual(frames[2].notes.count, 2)
            XCTAssertEqual(frames[0].notes[0].string, 1)
            XCTAssertEqual(frames[0].notes[0].fret, 5)
            XCTAssertFalse(frames.last!.notes[0].bend.isEmpty)
            let selection = track.selection(from: 2, through: 2)
            XCTAssertEqual(selection.count, 1)
            XCTAssertEqual(selection[0].start, 0)
            XCTAssertEqual(selection[0].end, 4)
            let events = ScorePlaybackTimeline.events(frames: frames, startIndex: 0, speed: 0.5)
            let onsets = events.compactMap { event -> Double? in
                if case .note = event.action { return event.time }; return nil
            }
            XCTAssertEqual(onsets, frames.dropFirst().map { $0.start * 2 })
            XCTAssertEqual(events.last!.time, 16)
            XCTAssertEqual(events.map(\.time), events.map(\.time).sorted())
            let resumed = ScorePlaybackTimeline.events(frames: frames, startIndex: 3, speed: 1)
            XCTAssertEqual(resumed.last!.time, 7)
        }
    }

    @MainActor
    func testRenderImportedScore() async throws {
        guard let output = ProcessInfo.processInfo.environment["FRETNOTE_GP_SNAPSHOT"] else { return }
        _ = NSApplication.shared
        let url = try XCTUnwrap(Bundle.module.url(forResource: "timing", withExtension: "gp5", subdirectory: "Fixtures"))
        let score = try GuitarProScore.load(url)
        let host = NSHostingView(rootView: GuitarProPlaybackView(score: score, close: {})
            .environment(\.appLanguage, .english).environment(\.interfaceScale, 1.75)
            .preferredColorScheme(.light).frame(width: 960, height: 620))
        let window = NSWindow(contentRect: NSRect(x: 0,y: 0,width: 960,height: 620),styleMask: [.borderless],backing: .buffered,defer: false)
        window.contentView = host; window.orderFront(nil)
        try await Task.sleep(nanoseconds: 500_000_000)
        host.layoutSubtreeIfNeeded()
        XCTAssertLessThanOrEqual(host.fittingSize.height, 620)
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        try XCTUnwrap(bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.75])).write(to: URL(fileURLWithPath: output))
        window.orderOut(nil)
    }

    func testInvalidInputIsRejected() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".gp5")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("not a score".utf8).write(to: url)
        XCTAssertThrowsError(try GuitarProScore.load(url))
    }
    func testLocalIntegrationScore() throws {
        guard let path = ProcessInfo.processInfo.environment["FRETNOTE_GP_TEST"] else { throw XCTSkip("Optional private score") }
        let score = try GuitarProScore.load(URL(fileURLWithPath: path))
        XCTAssertFalse(score.tracks.isEmpty)
        XCTAssertTrue(score.tracks[0].supported)
        XCTAssertTrue(score.tracks[0].frames.contains { !$0.notes.isEmpty })
        XCTAssertTrue(score.tracks[0].frames.allSatisfy { $0.end > $0.start })
        print("Imported \(score.title): \(score.tracks.count) guitar tracks; \(score.tracks[0].frames.count) frames")
    }
}
