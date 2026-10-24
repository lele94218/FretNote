import SwiftUI
import FretNoteCore

/// A readable scale diagram uses its own spacing instead of shrinking text onto the photo neck.
struct ScoreScaleFretboardView: View, Localizable {
    @Environment(\.appLanguage) var language
    @Environment(\.colorScheme) private var scheme
    @Environment(\.interfaceScale) private var scale
    let estimate: ScoreScaleEstimate?
    let positions: [GuitarNote]
    let active: [GuitarNote]
    let upcoming: [GuitarNote]
    let bends: [ScoreBendDisplay]

    private var firstFret: Int {
        let low = positions.map(\.fret).min() ?? 1
        let high = positions.map(\.fret).max() ?? low
        // A wide leap in the same bar must not shrink the whole diagram.
        let anchor = active.first?.fret ?? upcoming.first?.fret ?? low
        return max(0, min(16, high - low <= 4 ? low - 1 : anchor - 2))
    }
    private var lastFret: Int { firstFret + 5 }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(estimate.map { $0.tonicName + " " + L($0.kind.rawValue) + " · " + L("推测") } ?? L("音阶未确定"))
                .font(.editorial(size: 20 * scale, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7)
            Canvas { context, size in
                let left: CGFloat = 28, right = size.width - 28
                let top: CGFloat = 20, bottom = max(top + 50, size.height - 42)
                let spacing = (bottom - top) / 5
                let columns = lastFret - firstFret + 1
                let width = (right - left) / CGFloat(columns)
                let radius = min(19 * scale, spacing * 0.43, width * 0.38)
                let ink: Color = scheme == .dark ? .white : .black
                let paper: Color = scheme == .dark ? .black : .white
                func point(_ note: GuitarNote) -> CGPoint {
                    CGPoint(x: left + (CGFloat(note.fret - firstFret) + 0.5) * width,
                            y: top + CGFloat(note.string - 1) * spacing)
                }
                for column in 0...columns {
                    let x = left + CGFloat(column) * width
                    var line = Path(); line.move(to: CGPoint(x: x, y: top)); line.addLine(to: CGPoint(x: x, y: bottom))
                    context.stroke(line, with: .color(ink.opacity(0.3)), lineWidth: 1)
                }
                for string in 1...6 {
                    let y = top + CGFloat(string - 1) * spacing
                    var line = Path(); line.move(to: CGPoint(x: left, y: y)); line.addLine(to: CGPoint(x: right, y: y))
                    context.stroke(line, with: .color(ink.opacity(0.5)), lineWidth: 0.6 + Double(string) * 0.18)
                }
                for fret in firstFret...lastFret {
                    let x = left + (CGFloat(fret - firstFret) + 0.5) * width
                    context.draw(Text("\(fret)").font(.editorial(size: 13 * scale)).foregroundColor(ink), at: CGPoint(x: x, y: bottom + radius + 15))
                    if [3,5,7,9,12,15,17,19,21].contains(fret) {
                        for offset in (fret == 12 ? [-0.7, 0.7] : [0.0]) {
                            let rect = CGRect(x: x - 4, y: (top + bottom) / 2 + offset * spacing - 4, width: 8, height: 8)
                            context.fill(Path(ellipseIn: rect), with: .color(ink.opacity(0.15)))
                        }
                    }
                    for string in 1...6 {
                        let note = GuitarNote(string: string, fret: fret)
                        let current = active.contains(note), next = upcoming.contains(note)
                        let inScale = estimate.map { $0.kind.intervals.contains((note.midi - $0.tonic + 120) % 12) } ?? false
                        guard inScale || current || next else { continue }
                        let center = point(note)
                        let circle = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
                        let accent = GuitarStringPalette.color(string)
                        context.fill(circle, with: .color(current ? accent : ink))
                        if current || next { context.stroke(circle, with: .color(current ? paper : accent), lineWidth: 3) }
                        let label = estimate?.degree(midi: note.midi) ?? note.fullName
                        context.draw(Text(label).font(.editorial(size: radius * (label.count > 2 ? 0.85 : 1.15), weight: .semibold))
                            .foregroundColor(current ? .black : paper), at: center)
                        if let bend = bends.first(where: { $0.position == note }), current {
                            let target = CGPoint(x: center.x + radius * 1.5, y: center.y - radius * 1.2)
                            var arrow = Path(); arrow.move(to: CGPoint(x: center.x + radius * 0.6, y: center.y - radius * 0.6)); arrow.addLine(to: target)
                            arrow.addLine(to: CGPoint(x: target.x - 5, y: target.y)); arrow.move(to: target); arrow.addLine(to: CGPoint(x: target.x, y: target.y + 5))
                            context.stroke(arrow, with: .color(accent), lineWidth: 2)
                            context.draw(Text(bend.amountLabel).font(.editorial(size: 11 * scale)).foregroundColor(ink), at: CGPoint(x: target.x + 12, y: target.y - 5))
                        }
                    }
                }
            }
            .accessibilityLabel(L("音阶图"))
        }
    }
}
