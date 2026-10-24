import XCTest
import SwiftUI
@testable import FretNoteApp

final class ScoreBarTimelineTests: XCTestCase {
    func testBarsGroupFramesAndRetainRepeatOrder() {
        let frames: [GuitarProScore.Frame] = [
            .init(start: 0, end: 1, bar: 1, notes: []),
            .init(start: 1, end: 3, bar: 1, notes: []),
            .init(start: 3, end: 7, bar: 2, notes: []),
            .init(start: 7, end: 10, bar: 1, notes: [])
        ]
        let bars = ScoreBarSegment.make(frames: frames)
        XCTAssertEqual(bars.map(\.id), [0, 2, 3])
        XCTAssertEqual(bars.map(\.bar), [1, 2, 1])
        XCTAssertEqual(bars[0].end, 3)
        // Progress represents elapsed duration, not the number of notes.
        XCTAssertEqual(bars[0].progress(at: 1.5), 0.5)
        XCTAssertEqual(bars[1].progress(at: 5), 0.5)
        XCTAssertEqual(bars[1].progress(at: 0), 0)
        XCTAssertEqual(bars[1].progress(at: 20), 1)
        XCTAssertTrue(ScoreBarSegment.make(frames: []).isEmpty)
    }

    @MainActor
    func testPreview() throws {
        guard let path = ProcessInfo.processInfo.environment["FRETNOTE_TIMELINE_SNAPSHOT"] else { return }
        let bars = (0..<24).map { ScoreBarSegment(id: $0, bar: $0 + 1, start: Double($0 * 4), end: Double(($0 + 1) * 4), hasNotes: $0 != 9) }
        let view = ScoreBarTimeline(segments: bars, step: 6, position: 26, seek: { _ in })
            .padding(24).frame(width: 960, height: 110).background(Color.white)
            .environment(\.colorScheme, .light)
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: 960, height: 110)
        hosting.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        try XCTUnwrap(bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.75]))
            .write(to: URL(fileURLWithPath: path))
    }
}
