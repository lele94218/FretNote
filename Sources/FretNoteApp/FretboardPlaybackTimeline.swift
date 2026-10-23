import Foundation

/// Note deadlines belong to the playback clock. Camera cues never add duration.
enum FretboardPlaybackTimeline {
    static let noteInterval: TimeInterval = 1.2
    static let cameraLead: TimeInterval = 0.7
    static let cameraAnimation: TimeInterval = 0.55

    enum Action: Equatable {
        case frame(Int)
        case note(Int)
        case finish
    }
    struct Event: Equatable {
        let time: TimeInterval
        let action: Action
    }
    static func events(startIndex: Int, noteCount: Int) -> [Event] {
        guard startIndex >= 0, startIndex < noteCount else { return [] }
        var events: [Event] = []
        for index in (startIndex + 1)..<noteCount {
            let deadline = Double(index - startIndex) * noteInterval
            events.append(Event(time: deadline - cameraLead, action: .frame(index)))
            events.append(Event(time: deadline, action: .note(index)))
        }
        events.append(Event(time: Double(noteCount - startIndex) * noteInterval, action: .finish))
        return events
    }
}
