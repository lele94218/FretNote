import SwiftUI
import FretNoteCore

struct StaffView: View {
    let notes: [GuitarNote]
    let current: Int
    let showNames: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.interfaceScale) private var scale
    private var palette: AppPalette { AppPalette(scheme: colorScheme) }
    private var ink: Color { palette.ink }
    var body: some View {
        Canvas { context, physicalSize in
            context.scaleBy(x: scale, y: scale)
            let size = CGSize(width: physicalSize.width / scale, height: physicalSize.height / scale)
            let highest = max(10, (notes.map(\.staffStep).max() ?? 8) + 2)
            let lowest = min(-2, (notes.map(\.staffStep).min() ?? 0) - 2)
            let spacing = min(16, (size.height - 68) * 2 / CGFloat(highest - lowest))
            let bottom = 24 + CGFloat(highest) * spacing / 2
            let start: CGFloat = 90
            let end = size.width - 30
            for line in 0..<5 {
                let y = bottom - CGFloat(line) * spacing
                var path = Path(); path.move(to: CGPoint(x: 25, y: y)); path.addLine(to: CGPoint(x: end, y: y))
                context.stroke(path, with: .color(ink.opacity(0.35)), lineWidth: 1)
            }
            context.draw(Text("𝄞").font(.custom("Apple Symbols", size: spacing * 5.25)).foregroundColor(ink), at: CGPoint(x: 51, y: bottom - spacing * 1.25))
            context.draw(Text("8").font(.system(size: 12)).foregroundColor(ink.opacity(0.65)), at: CGPoint(x: 52, y: bottom + spacing * 1.6))
            let available = end - start
            var accidentals: [Int: Bool] = [:]
            for (i, note) in notes.enumerated() {
                let x = start + available * CGFloat(i + 1) / CGFloat(notes.count + 1)
                let y = bottom - CGFloat(note.staffStep) * spacing / 2
                let color = i < current ? palette.muted : ink
                if i == current {
                    context.draw(Text("↓").font(.system(size: 20)).foregroundColor(ink), at: CGPoint(x: x, y: 10))
                }
                if note.staffStep < 0 {
                    for step in stride(from: -2, through: note.staffStep, by: -2) { ledger(&context, x: x, y: bottom - CGFloat(step) * spacing / 2, color: color) }
                }
                if note.staffStep > 8 {
                    for step in stride(from: 10, through: note.staffStep, by: 2) { ledger(&context, x: x, y: bottom - CGFloat(step) * spacing / 2, color: color) }
                }
                context.fill(Path(ellipseIn: CGRect(x: x - 9, y: y - 6, width: 18, height: 12)), with: .color(color))
                var stem = Path()
                let down = note.staffStep >= 4
                stem.move(to: CGPoint(x: x + (down ? -8 : 8), y: y))
                stem.addLine(to: CGPoint(x: x + (down ? -8 : 8), y: y + (down ? 40 : -40)))
                context.stroke(stem, with: .color(color), lineWidth: 1.6)
                if !note.isNatural || accidentals[note.staffStep] == true {
                    context.draw(Text(note.isNatural ? "♮" : "♯").font(.system(size: 26)).foregroundColor(color), at: CGPoint(x: x - 22, y: y - 1))
                }
                accidentals[note.staffStep] = !note.isNatural
                if showNames {
                    context.draw(Text(note.name).font(.system(size: 16, weight: .medium)).foregroundColor(color), at: CGPoint(x: x, y: size.height - 22))
                }
            }
        }
        .accessibilityLabel("吉他高音谱表，实际发声低八度")
        .accessibilityValue(notes.map(\.fullName).joined(separator: "，"))
    }
    private func ledger(_ context: inout GraphicsContext, x: CGFloat, y: CGFloat, color: Color) {
        var path = Path(); path.move(to: CGPoint(x: x - 15, y: y)); path.addLine(to: CGPoint(x: x + 15, y: y))
        context.stroke(path, with: .color(color.opacity(0.7)), lineWidth: 1)
    }
}

/// A local fretboard segment, with neighboring frets for position context.
/// The open-string column sits to the left of the nut, not inside a fret.
struct FretboardView: View {
    let lower: Int
    let upper: Int
    var highlightedNote: GuitarNote? = nil
    var emphasizedString: Int? = nil
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.interfaceScale) private var scale
    private var palette: AppPalette { AppPalette(scheme: colorScheme) }

    private var firstFret: Int { max(0, lower - 1) }
    private var lastFret: Int { min(24, upper + 1) }
    private let tuning = ["E4", "B3", "G3", "D3", "A2", "E2"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("把位 · \(lower == 0 ? "空弦" : "第 \(lower) 品")–第 \(upper) 品")
                Spacer()
                if let note = highlightedNote {
                    Text("参考位置：\(note.string) 弦 · \(note.fret == 0 ? "空弦" : "第 \(note.fret) 品")")
                } else {
                    Text("灰色区域为练习范围")
                }
            }
            .font(.system(size: 12 * scale)).foregroundStyle(palette.muted)

            Canvas { context, physicalSize in
            context.scaleBy(x: scale, y: scale)
            let size = CGSize(width: physicalSize.width / scale, height: physicalSize.height / scale)
                let left: CGFloat = 64
                let right = size.width - 12
                let top: CGFloat = 12
                let bottom: CGFloat = 112
                let count = lastFret - firstFret + 1
                let cell = (right - left) / CGFloat(count)
                let selectionX = left + CGFloat(lower - firstFret) * cell
                let selection = CGRect(x: selectionX, y: top - 8,
                                       width: CGFloat(upper - lower + 1) * cell,
                                       height: bottom - top + 16)
                context.fill(Path(selection), with: .color(palette.selection))

                for string in 1...6 {
                    let y = top + CGFloat(string - 1) * 20
                    let emphasized = emphasizedString == nil || emphasizedString == string
                    let color = palette.ink.opacity(emphasized ? 0.55 : 0.2)
                    context.draw(Text("\(string)  \(tuning[string - 1])")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(color), at: CGPoint(x: left - 12, y: y), anchor: .trailing)
                    var line = Path()
                    line.move(to: CGPoint(x: left, y: y))
                    line.addLine(to: CGPoint(x: right, y: y))
                    context.stroke(line, with: .color(color), lineWidth: 0.6 + Double(string) * 0.13)
                }
                for fret in firstFret...lastFret {
                    let x = left + CGFloat(fret - firstFret) * cell
                    let inRange = (lower...upper).contains(fret)
                    let color = palette.ink.opacity(inRange ? 0.8 : 0.35)
                    context.draw(Text(fret == 0 ? "空弦" : "\(fret)")
                        .font(.system(size: 12)).foregroundColor(color),
                        at: CGPoint(x: x + cell / 2, y: 138))
                    var wire = Path()
                    wire.move(to: CGPoint(x: x + cell, y: top))
                    wire.addLine(to: CGPoint(x: x + cell, y: bottom))
                    context.stroke(wire, with: .color(palette.ink.opacity(fret == 0 ? 0.75 : 0.25)),
                                   lineWidth: fret == 0 ? 3 : 1)
                }
                // Close the left edge only when the segment begins above the nut.
                if firstFret > 0 {
                    var edge = Path()
                    edge.move(to: CGPoint(x: left, y: top))
                    edge.addLine(to: CGPoint(x: left, y: bottom))
                    context.stroke(edge, with: .color(palette.ink.opacity(0.25)), lineWidth: 1)
                }
                if let note = highlightedNote,
                   (firstFret...lastFret).contains(note.fret), (1...6).contains(note.string) {
                    let x = left + (CGFloat(note.fret - firstFret) + 0.5) * cell
                    let y = top + CGFloat(note.string - 1) * 20
                    let dot = Path(ellipseIn: CGRect(x: x - 8, y: y - 8, width: 16, height: 16))
                    context.fill(dot, with: .color(note.fret == 0 ? palette.background : palette.ink))
                    if note.fret == 0 { context.stroke(dot, with: .color(palette.ink), lineWidth: 2) }
                }
            }
            .frame(height: 150 * scale)
            .accessibilityLabel("吉他指板，一弦在上，六弦在下；练习范围第 \(lower) 到 \(upper) 品")
            .accessibilityValue(highlightedNote.map { "参考位置：第 \($0.string) 弦，第 \($0.fret) 品" } ?? "未显示答案位置")
        }
    }
}
