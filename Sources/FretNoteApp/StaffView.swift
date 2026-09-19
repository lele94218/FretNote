import SwiftUI
import FretNoteCore

/// Drawing dimensions depend on notation and text size, never on the window width.
/// Extra room becomes margins; a narrow viewport scrolls horizontally.
struct FixedDiagram<Content: View>: View {
    let size: CGSize
    var focusX: CGFloat? = nil
    @ViewBuilder let content: () -> Content
    @Environment(\.interfaceScale) private var scale
    var body: some View {
        GeometryReader { viewport in
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        content()
                            .frame(width: size.width, height: size.height)
                            .overlay(alignment: .topLeading) {
                                if let focusX {
                                    HStack(spacing: 0) {
                                        Color.clear.frame(width: max(0, focusX), height: 1)
                                        Color.clear.frame(width: 1, height: 1).id("current-target")
                                        Spacer(minLength: 0)
                                    }.allowsHitTesting(false).accessibilityHidden(true)
                                }
                            }
                            .frame(minWidth: viewport.size.width)
                    }
                    .onAppear { proxy.scrollTo("current-target", anchor: .center) }
                    .onChange(of: focusX) { _ in proxy.scrollTo("current-target", anchor: .center) }
                    .onChange(of: viewport.size.width) { _ in proxy.scrollTo("current-target", anchor: .center) }
                }
                .frame(height: size.height)
                if viewport.size.width < size.width {
                    Text("← 左右滚动查看 →")
                        .font(.system(size: 11 * scale)).foregroundStyle(.secondary)
                }
            }
        }
        .frame(height: size.height + 20 * scale)
    }
}

struct StaffView: View {
    let notes: [GuitarNote]
    let current: Int
    let showNames: Bool
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.interfaceScale) private var scale
    private var palette: AppPalette { AppPalette(scheme: colorScheme, contrast: contrast) }
    private var highest: Int { max(10, (notes.map(\.staffStep).max() ?? 8) + 2) }
    private var lowest: Int { min(-2, (notes.map(\.staffStep).min() ?? 0) - 2) }
    private var bottom: CGFloat { 30 + CGFloat(highest) * 7 }
    private var width: CGFloat { max(300, 200 + CGFloat(max(0, notes.count - 1)) * 72) }
    private var labelY: CGFloat { bottom - CGFloat(lowest) * 7 + 18 }
    private var height: CGFloat { labelY + (showNames ? 22 : 8) }

    var body: some View {
        FixedDiagram(size: CGSize(width: width * scale, height: height * scale),
                     focusX: ((notes.count == 1 ? 170 : 140) + CGFloat(min(current, max(0, notes.count - 1))) * 72) * scale) {
            Canvas { context, _ in
                context.scaleBy(x: scale, y: scale)
                let ink = palette.ink
                for line in 0..<5 {
                    let y = bottom - CGFloat(line) * 14
                    var path = Path()
                    path.move(to: CGPoint(x: 18, y: y))
                    path.addLine(to: CGPoint(x: width - 18, y: y))
                    context.stroke(path, with: .color(ink.opacity(contrast == .increased ? 0.85 : 0.55)), lineWidth: 1)
                }
                context.draw(Text("𝄞").font(.custom("Apple Symbols", size: 73.5)).foregroundColor(ink),
                             at: CGPoint(x: 43, y: bottom - 17.5))
                context.draw(Text("8").font(.system(size: 12)).foregroundColor(palette.muted),
                             at: CGPoint(x: 44, y: bottom + 23))
                var accidentals: [Int: Bool] = [:]
                let firstX: CGFloat = notes.count == 1 ? 170 : 140
                for (i, note) in notes.enumerated() {
                    let x = firstX + CGFloat(i) * 72
                    let y = bottom - CGFloat(note.staffStep) * 7
                    let color = i < current ? palette.muted : ink
                    if i == current {
                        context.draw(Text("↓").font(.system(size: 18)).foregroundColor(ink), at: CGPoint(x: x, y: 12))
                    }
                    if note.staffStep < 0 {
                        for step in stride(from: -2, through: note.staffStep, by: -2) {
                            ledger(&context, x: x, y: bottom - CGFloat(step) * 7, color: color)
                        }
                    }
                    if note.staffStep > 8 {
                        for step in stride(from: 10, through: note.staffStep, by: 2) {
                            ledger(&context, x: x, y: bottom - CGFloat(step) * 7, color: color)
                        }
                    }
                    let head = Path(ellipseIn: CGRect(x: -8, y: -5, width: 16, height: 10))
                        .applying(CGAffineTransform(rotationAngle: -.pi / 8))
                        .applying(CGAffineTransform(translationX: x, y: y))
                    context.fill(head, with: .color(color))
                    let down = note.staffStep >= 4
                    var stem = Path()
                    stem.move(to: CGPoint(x: x + (down ? -7 : 7), y: y))
                    stem.addLine(to: CGPoint(x: x + (down ? -7 : 7), y: y + (down ? 35 : -35)))
                    context.stroke(stem, with: .color(color), lineWidth: 1.4)
                    if !note.isNatural || accidentals[note.staffStep] == true {
                        context.draw(Text(note.isNatural ? "♮" : "♯").font(.system(size: 23)).foregroundColor(color),
                                     at: CGPoint(x: x - 21, y: y - 1))
                    }
                    accidentals[note.staffStep] = !note.isNatural
                    if showNames {
                        context.draw(Text(note.name).font(.system(size: 15, weight: .medium)).foregroundColor(color),
                                     at: CGPoint(x: x, y: labelY))
                    }
                }
            }
        }
        .accessibilityLabel("吉他高音谱表，实际发声低八度")
        .accessibilityValue((notes.indices.contains(current) ? "当前第 \(current + 1) 个音：\(notes[current].fullName)。" : "本题完成。") + "全曲：" + notes.map(\.fullName).joined(separator: "，"))
    }
    private func ledger(_ context: inout GraphicsContext, x: CGFloat, y: CGFloat, color: Color) {
        var path = Path()
        path.move(to: CGPoint(x: x - 13, y: y))
        path.addLine(to: CGPoint(x: x + 13, y: y))
        context.stroke(path, with: .color(color.opacity(0.7)), lineWidth: 1)
    }
}

/// Equal-tempered fret spacing. Later frets are physically closer together.
/// Open strings sit to the left of the nut, outside the fretted neck.
struct FretboardView: View {
    let lower: Int
    let upper: Int
    var highlightedNote: GuitarNote? = nil
    var emphasizedString: Int? = nil
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.interfaceScale) private var scale
    private var palette: AppPalette { AppPalette(scheme: colorScheme, contrast: contrast) }
    private var firstFret: Int { max(0, lower - 1) }
    private var lastFret: Int { min(24, upper + 1) }
    private let tuning = ["E4", "B3", "G3", "D3", "A2", "E2"]
    private func fretWidth(_ fret: Int) -> CGFloat {
        fret == 0 ? 40 : 72 * pow(2, -Double(fret - 1) / 12)
    }
    private func fretLeft(_ fret: Int) -> CGFloat {
        (firstFret..<fret).reduce(CGFloat(64)) { $0 + fretWidth($1) }
    }
    private var right: CGFloat { fretLeft(lastFret) + fretWidth(lastFret) }
    private var neckLeft: CGFloat { firstFret == 0 ? fretLeft(1) : 64 }
    private func stringY(_ string: Int) -> CGFloat { 24 + CGFloat(string - 1) * 14 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    rangeLabel
                    Spacer(minLength: 16)
                    hintLabel
                }
                VStack(alignment: .leading, spacing: 5) { rangeLabel; hintLabel }
            }
            .font(.system(size: 12 * scale)).foregroundStyle(palette.muted)
            FixedDiagram(size: CGSize(width: (right + 14) * scale, height: 140 * scale),
                         focusX: highlightedNote.flatMap { note in
                             guard (firstFret...lastFret).contains(note.fret) else { return nil }
                             return (fretLeft(note.fret) + fretWidth(note.fret) / 2) * scale
                         }) {
                Canvas { context, _ in
                    context.scaleBy(x: scale, y: scale)
                    let ink = palette.ink
                    let selectionLeft = fretLeft(lower)
                    let selectionRight = fretLeft(upper) + fretWidth(upper)
                    context.fill(Path(CGRect(x: selectionLeft, y: 14, width: selectionRight - selectionLeft, height: 90)),
                                 with: .color(palette.selection))
                    // Neck edges and fret wires. The left boundary is the nut only at fret zero.
                    var edges = Path()
                    edges.move(to: CGPoint(x: neckLeft, y: 14))
                    edges.addLine(to: CGPoint(x: right, y: 14))
                    edges.move(to: CGPoint(x: neckLeft, y: 104))
                    edges.addLine(to: CGPoint(x: right, y: 104))
                    context.stroke(edges, with: .color(ink.opacity(0.3)), lineWidth: 1)
                    for fret in firstFret...lastFret {
                        let left = fretLeft(fret)
                        let center = left + fretWidth(fret) / 2
                        let inRange = (lower...upper).contains(fret)
                        context.draw(Text(fret == 0 ? "空弦" : "\(fret)").font(.system(size: 12))
                            .foregroundColor(inRange ? ink : palette.muted), at: CGPoint(x: center, y: 126))
                        var wire = Path()
                        wire.move(to: CGPoint(x: left + fretWidth(fret), y: 14))
                        wire.addLine(to: CGPoint(x: left + fretWidth(fret), y: 104))
                        context.stroke(wire, with: .color(ink.opacity(contrast == .increased ? 0.85 : (fret == 0 ? 0.8 : 0.35))), lineWidth: fret == 0 ? 3.5 : 1)
                        let markerYs: [CGFloat] = [12, 24].contains(fret) ? [45, 73] : ([3, 5, 7, 9, 15, 17, 19, 21].contains(fret) ? [59] : [])
                        for y in markerYs {
                            context.fill(Path(ellipseIn: CGRect(x: center - 3, y: y - 3, width: 6, height: 6)),
                                         with: .color(ink.opacity(0.22)))
                        }
                    }
                    if firstFret > 0 {
                        var edge = Path()
                        edge.move(to: CGPoint(x: 64, y: 14)); edge.addLine(to: CGPoint(x: 64, y: 104))
                        context.stroke(edge, with: .color(ink.opacity(0.3)), lineWidth: 1)
                    }
                    for string in 1...6 {
                        let y = stringY(string)
                        let emphasized = emphasizedString == nil || emphasizedString == string
                        let color = ink.opacity(contrast == .increased ? (emphasized ? 1 : 0.65) : (emphasized ? 0.7 : 0.25))
                        context.draw(Text("\(string)  \(tuning[string - 1])").font(.system(size: 12, design: .monospaced))
                            .foregroundColor(color), at: CGPoint(x: 52, y: y), anchor: .trailing)
                        var line = Path()
                        line.move(to: CGPoint(x: 64, y: y)); line.addLine(to: CGPoint(x: right, y: y))
                        context.stroke(line, with: .color(color), lineWidth: 0.5 + Double(string) * 0.18)
                    }
                    if let note = highlightedNote, (firstFret...lastFret).contains(note.fret), (1...6).contains(note.string) {
                        let x = fretLeft(note.fret) + fretWidth(note.fret) / 2
                        let y = stringY(note.string)
                        let dot = Path(ellipseIn: CGRect(x: x - 6, y: y - 6, width: 12, height: 12))
                        context.fill(dot, with: .color(note.fret == 0 ? palette.background : ink))
                        if note.fret == 0 { context.stroke(dot, with: .color(ink), lineWidth: 1.5) }
                    }
                }
            }
            .accessibilityLabel("吉他指板，一弦在上，六弦在下；练习范围第 \(lower) 到 \(upper) 品")
            .accessibilityValue(highlightedNote.map { "参考位置：第 \($0.string) 弦，第 \($0.fret) 品" } ?? "未显示答案位置")
        }
    }
    private var rangeLabel: some View {
        Text("把位 · \(lower == 0 ? "空弦" : "第 \(lower) 品")–第 \(upper) 品").fixedSize()
    }
    private var hintLabel: some View {
        Group {
            if let note = highlightedNote {
                Text("参考位置：\(note.string) 弦 · \(note.fret == 0 ? "空弦" : "第 \(note.fret) 品")")
            } else { Text("灰色区域为练习范围") }
        }.fixedSize()
    }
}
