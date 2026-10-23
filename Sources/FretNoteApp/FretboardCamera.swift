import SwiftUI
import FretNoteCore

struct FretboardCamera: Equatable {
    var center: CGFloat
    var width: CGFloat
    static let overview = FretboardCamera(center: 590, width: 1900)
    static func following(_ notes: [GuitarNote], index: Int) -> FretboardCamera {
        guard notes.indices.contains(index) else { return .overview }
        let upcoming = notes[index..<min(notes.count, index + 3)]
        let xs = upcoming.map { GuitarGeometry.noteX($0.fret) }
        let left = (xs.min() ?? 0) - 100
        let right = (xs.max() ?? 0) + 100
        let width = min(overview.width, max(370, right - left))
        let center = min(overview.center + overview.width / 2 - width / 2,
                         max(overview.center - overview.width / 2 + width / 2, (left + right) / 2))
        return FretboardCamera(center: center, width: width)
    }
}

enum GuitarGeometry {
    static let maximumFret = 21
    static let scaleLength: CGFloat = 1200
    static func fretX(_ fret: Int) -> CGFloat {
        scaleLength * (1 - pow(2, -CGFloat(max(0, min(maximumFret, fret))) / 12))
    }
    static func noteX(_ fret: Int) -> CGFloat {
        fret <= 0 ? -28 : (fretX(fret - 1) + fretX(fret)) / 2
    }
    static func stringY(_ string: Int, x: CGFloat) -> CGFloat {
        let spread = 62 + min(1, max(0, x / scaleLength)) * 28
        return (CGFloat(string) - 3.5) * spread / 5
    }
    static func markerRadius(x: CGFloat, zoom: CGFloat) -> CGFloat {
        let gap = stringY(2, x: x) - stringY(1, x: x)
        return min(9 / max(zoom, 0.001), gap * 0.30)
    }
    static let demo: [GuitarNote] = [(6, 0), (6, 3), (5, 2), (4, 2), (3, 5), (2, 5),
        (1, 5), (1, 8), (2, 10), (1, 12), (2, 13), (1, 15), (1, 17), (1, 19), (1, 21),
        (2, 17), (3, 14), (2, 10), (3, 9), (4, 7), (5, 3), (6, 0)].map { GuitarNote(string: $0.0, fret: $0.1) }
}
