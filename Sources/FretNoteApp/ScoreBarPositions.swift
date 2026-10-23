import FretNoteCore

/// All physical positions in the current occurrence of a bar, including notes
/// already played. Repeated notes on the same string/fret share one marker.
enum ScoreBarPositions {
    static func positions(in frames: [GuitarProScore.Frame], at index: Int) -> [GuitarNote] {
        guard frames.indices.contains(index) else { return [] }
        let bar = frames[index].bar
        var start = index, end = index + 1
        while start > 0 && frames[start - 1].bar == bar { start -= 1 }
        while end < frames.count && frames[end].bar == bar { end += 1 }
        var result: [GuitarNote] = []
        for note in frames[start..<end].flatMap(\.positions) where !result.contains(note) { result.append(note) }
        return result
    }
}
