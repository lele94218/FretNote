import XCTest
@testable import FretNoteApp

final class FretboardPlaybackTimelineTests: XCTestCase {
    func testCameraCuesDoNotAddTimeBetweenNotes() {
        let events = FretboardPlaybackTimeline.events(startIndex: 0, noteCount: 200)
        let onsets = events.compactMap { event -> Double? in
            if case .note = event.action { return event.time }
            return nil
        }
        XCTAssertEqual(onsets.count, 199)
        for (index, onset) in onsets.enumerated() {
            XCTAssertEqual(onset, Double(index + 1) * 1.2, accuracy: 0.000001)
            let cue = events.first { $0.action == .frame(index + 1) }!
            XCTAssertLessThan(cue.time + FretboardPlaybackTimeline.cameraAnimation, onset)
            XCTAssertEqual(onset - cue.time, 0.7, accuracy: 0.000001)
        }
        XCTAssertEqual(events.last?.action, .finish)
        XCTAssertEqual(events.last!.time, 240, accuracy: 0.000001)
        XCTAssertEqual(events.map(\.time), events.map(\.time).sorted())
    }

    func testResumeAndFinalNoteKeepTheirFullDuration() {
        let resumed = FretboardPlaybackTimeline.events(startIndex: 7, noteCount: 10)
        XCTAssertEqual(resumed.filter { if case .note = $0.action { return true }; return false }, [
            .init(time: 1.2, action: .note(8)), .init(time: 2.4, action: .note(9))
        ])
        XCTAssertEqual(resumed.last!.time, 3.6, accuracy: 0.000001)
        XCTAssertEqual(FretboardPlaybackTimeline.events(startIndex: 9, noteCount: 10), [.init(time: 1.2, action: .finish)])
        XCTAssertTrue(FretboardPlaybackTimeline.events(startIndex: 0, noteCount: 0).isEmpty)
        XCTAssertTrue(FretboardPlaybackTimeline.events(startIndex: 10, noteCount: 10).isEmpty)
    }
}
