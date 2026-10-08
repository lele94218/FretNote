import SwiftUI
import FretNoteCore

/// Fit drawings uniformly into their allotted space; never stretch or scroll them.
struct FixedDiagram<Content: View>: View {
    let size: CGSize
    @ViewBuilder let content: () -> Content
    var body: some View {
        GeometryReader { viewport in
            let factor = min(viewport.size.width / size.width, viewport.size.height / size.height)
            content()
                .frame(width: size.width, height: size.height)
                .scaleEffect(max(0, factor))
                .frame(width: viewport.size.width, height: viewport.size.height)
        }
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
    private let unit = MusicEngraving.space
    private var topExtent: CGFloat {
        min(-unit + MusicEngraving.clef.boundingRect.minY,
            notes.map { -CGFloat($0.staffStep) * unit / 2 - ($0.staffStep < 4 ? MusicEngraving.stemLength : unit * 1.5) }.min() ?? -unit * 4)
    }
    private var bottomExtent: CGFloat {
        max(-unit + MusicEngraving.clef.boundingRect.maxY,
            notes.map { -CGFloat($0.staffStep) * unit / 2 + ($0.staffStep >= 4 ? MusicEngraving.stemLength : unit * 1.5) }.max() ?? 0)
    }
    private var bottom: CGFloat { 36 - topExtent }
    private var firstX: CGFloat { notes.count == 1 ? 130 : 100 }
    private var width: CGFloat { max(210, firstX + CGFloat(max(0, notes.count - 1)) * 50 + 36) }
    private var labelY: CGFloat { bottom + bottomExtent + 20 }
    private var height: CGFloat { labelY + (showNames ? 14 : 0) }

    var body: some View {
        FixedDiagram(size: CGSize(width: width * scale, height: height * scale)) {
            Canvas { context, _ in
                context.scaleBy(x: scale, y: scale)
                let ink = palette.ink
                for line in 0..<5 {
                    let y = bottom - CGFloat(line) * 14
                    var path = Path()
                    path.move(to: CGPoint(x: 18, y: y))
                    path.addLine(to: CGPoint(x: width - 18, y: y))
                    context.stroke(path, with: .color(ink.opacity(contrast == .increased ? 1 : 0.7)), lineWidth: MusicEngraving.engraving("staffLineThickness"))
                }
                context.fill(MusicEngraving.clef.applying(CGAffineTransform(translationX: 28, y: bottom - unit)), with: .color(ink))
                var accidentals: [Int: Bool] = [:]
                for (i, note) in notes.enumerated() {
                    let x = firstX + CGFloat(i) * 50
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
                    let left = x - MusicEngraving.headWidth / 2
                    let outline = note.staffStep >= 4 ? MusicEngraving.downStem : MusicEngraving.upStem
                    let placement = CGAffineTransform(translationX: left, y: y)
                    context.fill(outline.applying(placement), with: .color(color))
                    context.fill(MusicEngraving.head.applying(placement), with: .color(color))
                    if !note.isNatural || accidentals[note.staffStep] == true {
                        let accidental = note.isNatural ? MusicEngraving.natural : MusicEngraving.sharp
                        let origin = left - unit * 0.4 - accidental.boundingRect.maxX
                        context.fill(accidental.applying(CGAffineTransform(translationX: origin, y: y)), with: .color(color))
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
        path.move(to: CGPoint(x: x - MusicEngraving.headWidth / 2 - MusicEngraving.engraving("legerLineExtension"), y: y))
        path.addLine(to: CGPoint(x: x + MusicEngraving.headWidth / 2 + MusicEngraving.engraving("legerLineExtension"), y: y))
        context.stroke(path, with: .color(color), lineWidth: MusicEngraving.engraving("legerLineThickness"))
    }
}

/// Equal-tempered fret spacing. Later frets are physically closer together.
/// Open strings sit to the left of the nut, outside the fretted neck.
struct FretboardView: View {
    let lower: Int
    let upper: Int
    var highlightedNote: GuitarNote? = nil
    var emphasizedString: Int? = nil
    var learningTones: [LearningTone] = []
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.interfaceScale) private var scale
    private var palette: AppPalette { AppPalette(scheme: colorScheme, contrast: contrast) }
    private var firstFret: Int { max(0, lower - 1) }
    private var lastFret: Int { min(PracticeStore.maximumFret, upper + 1) }
    private func fretWidth(_ fret: Int) -> CGFloat {
        fret == 0 ? 40 : 72 * pow(2, -Double(fret - 1) / 12)
    }
    private func fretLeft(_ fret: Int) -> CGFloat {
        (firstFret..<fret).reduce(CGFloat(14)) { $0 + fretWidth($1) }
    }
    private var right: CGFloat { fretLeft(lastFret) + fretWidth(lastFret) }
    private var neckLeft: CGFloat { firstFret == 0 ? fretLeft(1) : 14 }
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
            FixedDiagram(size: CGSize(width: (right + 14) * scale, height: 144 * scale)) {
                Canvas { context, _ in
                    context.scaleBy(x: scale, y: scale)
                    let ink = palette.ink
                    let neck = Path { path in
                        path.move(to: CGPoint(x: neckLeft, y: 14))
                        path.addLine(to: CGPoint(x: right, y: 10))
                        path.addLine(to: CGPoint(x: right, y: 108))
                        path.addLine(to: CGPoint(x: neckLeft, y: 104))
                        path.closeSubpath()
                    }
                    // Matte ebony, with a slightly widening neck rather than a boxed grid.
                    context.fill(neck, with: .color(Color(white: colorScheme == .dark ? 0.16 : 0.12)))
                    for edge in [0, 1] {
                        var binding = Path()
                        binding.move(to: CGPoint(x: neckLeft, y: edge == 0 ? 15 : 103))
                        binding.addLine(to: CGPoint(x: right, y: edge == 0 ? 11 : 107))
                        context.stroke(binding, with: .color(Color(white: 0.38)), lineWidth: 1.2)
                    }
                    for fret in firstFret...lastFret {
                        let left = fretLeft(fret)
                        let center = left + fretWidth(fret) / 2
                        let inRange = (lower...upper).contains(fret)
                        context.draw(Text(fret == 0 ? "空弦" : "\(fret)").font(.system(size: 11))
                            .foregroundColor(inRange ? ink : palette.muted), at: CGPoint(x: center, y: 132))
                        let x = left + fretWidth(fret)
                        let taper = max(0, (x - neckLeft) / (right - neckLeft)) * 4
                        let wireWidth: CGFloat = fret == 0 ? 4.5 : 2.3
                        let wire = Path(roundedRect: CGRect(x: x - wireWidth / 2, y: 14 - taper,
                                                           width: wireWidth, height: 90 + taper * 2),
                                        cornerRadius: wireWidth / 2)
                        context.fill(wire, with: .color(Color(white: fret == 0 ? 0.88 : 0.48)))
                        var shine = Path()
                        shine.move(to: CGPoint(x: x - 0.35, y: 15 - taper))
                        shine.addLine(to: CGPoint(x: x - 0.35, y: 103 + taper))
                        context.stroke(shine, with: .color(Color(white: 0.77)), lineWidth: 0.65)
                        let markerYs: [CGFloat] = fret == 12 ? [45, 73] : ([3, 5, 7, 9, 15, 17, 19, 21].contains(fret) ? [59] : [])
                        for y in markerYs {
                            context.fill(Path(ellipseIn: CGRect(x: center - 3.8, y: y - 3.8, width: 7.6, height: 7.6)),
                                         with: .color(Color(white: 0.68)))
                        }
                    }
                    // Strings sit above the fret wires. Wound bass strings are visibly thicker.
                    for string in 1...6 {
                        let y = stringY(string)
                        let emphasized = emphasizedString == nil || emphasizedString == string
                        let gauge: CGFloat = [0.65, 0.8, 1.05, 1.5, 2.0, 2.6][string - 1]
                        var shadow = Path()
                        shadow.move(to: CGPoint(x: 14, y: y + 1.2))
                        shadow.addLine(to: CGPoint(x: right, y: y + 1.2))
                        context.stroke(shadow, with: .color(.black.opacity(0.55)), lineWidth: gauge + 0.8)
                        var line = Path()
                        line.move(to: CGPoint(x: 14, y: y))
                        line.addLine(to: CGPoint(x: right, y: y))
                        context.stroke(line, with: .color(Color(white: emphasized ? 0.72 : 0.4)), lineWidth: gauge)
                        context.stroke(line, with: .color(Color(white: emphasized ? 0.96 : 0.55)), lineWidth: max(0.35, gauge * 0.28))
                        if firstFret == 0 {
                            var openString = Path()
                            openString.move(to: CGPoint(x: 14, y: y))
                            openString.addLine(to: CGPoint(x: neckLeft - 2.5, y: y))
                            context.stroke(openString, with: .color(ink.opacity(emphasized ? 0.7 : 0.35)), lineWidth: gauge)
                        }
                    }
                    let selectionLeft = fretLeft(lower)
                    let selectionRight = fretLeft(upper) + fretWidth(upper)
                    let range = Path(roundedRect: CGRect(x: selectionLeft, y: 116, width: selectionRight - selectionLeft, height: 2), cornerRadius: 1)
                    context.fill(range, with: .color(ink))
                    for tone in learningTones where (firstFret...lastFret).contains(tone.note.fret) {
                        let x = fretLeft(tone.note.fret) + fretWidth(tone.note.fret) / 2
                        let y = stringY(tone.note.string)
                        let marker = Path(roundedRect: CGRect(x: x - 10, y: y - 6.5, width: 20, height: 13), cornerRadius: 5)
                        context.fill(marker, with: .color(.white))
                        context.stroke(marker, with: .color(.black), lineWidth: tone.degree == "1" ? 1.5 : 0.7)
                        context.draw(Text(tone.degree).font(.system(size: 9, weight: .bold)).foregroundColor(.black), at: CGPoint(x: x, y: y))
                    }
                    if let note = highlightedNote, (firstFret...lastFret).contains(note.fret), (1...6).contains(note.string) {
                        let x = fretLeft(note.fret) + fretWidth(note.fret) / 2
                        let y = stringY(note.string)
                        let dot = Path(ellipseIn: CGRect(x: x - 6, y: y - 6, width: 12, height: 12))
                        context.fill(dot, with: .color(note.fret == 0 ? palette.background : .white))
                        context.stroke(dot, with: .color(note.fret == 0 ? ink : .black), lineWidth: 1.5)
                    }
                }
            }
            .frame(maxHeight: 160)
            .accessibilityLabel("吉他指板，一弦在上，六弦在下；练习范围第 \(lower) 到 \(upper) 品")
            .accessibilityValue(!learningTones.isEmpty ? learningTones.map { "\($0.name)，\($0.degree)，第 \($0.note.string) 弦第 \($0.note.fret) 品" }.joined(separator: "；") : highlightedNote.map { "参考位置：第 \($0.string) 弦，第 \($0.fret) 品" } ?? "未显示答案位置")
        }
    }
    private var rangeLabel: some View {
        Text("把位 · \(lower == 0 ? "空弦" : "第 \(lower) 品")–第 \(upper) 品").fixedSize()
    }
    private var hintLabel: some View {
        Group {
            if let note = highlightedNote {
                Text("参考位置：\(note.string) 弦 · \(note.fret == 0 ? "空弦" : "第 \(note.fret) 品")")
            } else { Text("一弦在上 · 六弦在下") }
        }.fixedSize()
    }
}
