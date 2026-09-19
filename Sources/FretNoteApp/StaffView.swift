import SwiftUI
import FretNoteCore

struct StaffView: View {
    let notes: [GuitarNote]
    let current: Int
    let showNames: Bool
    private let ink = Color(red: 0.83, green: 0.88, blue: 0.9)
    private let mint = Color(red: 0.39, green: 0.89, blue: 0.74)
    var body: some View {
        Canvas { context, size in
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
            context.draw(Text("8").font(.system(size: 11)).foregroundColor(ink.opacity(0.65)), at: CGPoint(x: 52, y: bottom + spacing * 1.6))
            let available = end - start
            var accidentals: [Int: Bool] = [:]
            for (i, note) in notes.enumerated() {
                let x = start + available * CGFloat(i + 1) / CGFloat(notes.count + 1)
                let y = bottom - CGFloat(note.staffStep) * spacing / 2
                let color = i < current ? mint : (i == current ? Color.white : ink.opacity(0.6))
                if i == current {
                    context.fill(Path(roundedRect: CGRect(x: x - 27, y: 16, width: 54, height: size.height - 32), cornerRadius: 14), with: .color(mint.opacity(0.09)))
                    context.fill(Path(ellipseIn: CGRect(x: x - 3, y: 7, width: 6, height: 6)), with: .color(mint))
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
                    context.draw(Text(note.name).font(.system(size: 16, weight: .medium, design: .rounded)).foregroundColor(color), at: CGPoint(x: x, y: size.height - 22))
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

struct FretboardHint: View {
    let note: GuitarNote
    let lower: Int
    let upper: Int
    var body: some View {
        VStack(spacing: 8) {
            Text("参考位置 · 第 \(note.string) 弦 · \(note.fret == 0 ? "空弦" : "第 \(note.fret) 品")")
                .font(.system(size: 14, weight: .medium)).foregroundStyle(.mint)
            Canvas { context, size in
                let width = size.width - 36
                let count = upper - lower + 1
                for s in 1...6 {
                    let y = CGFloat(s - 1) * 13 + 15
                    var path = Path(); path.move(to: CGPoint(x: 18, y: y)); path.addLine(to: CGPoint(x: size.width - 18, y: y))
                    context.stroke(path, with: .color(.white.opacity(0.25)), lineWidth: 0.6 + Double(s) * 0.15)
                }
                for f in 0...count {
                    let x = 18 + CGFloat(f) * width / CGFloat(count)
                    var path = Path(); path.move(to: CGPoint(x: x, y: 15)); path.addLine(to: CGPoint(x: x, y: 80))
                    context.stroke(path, with: .color(.white.opacity(0.2)), lineWidth: 1)
                    if f < count {
                        context.draw(Text("\(lower + f)").font(.system(size: 10)).foregroundColor(.gray), at: CGPoint(x: x + width / CGFloat(count) / 2, y: 98))
                    }
                }
                let x = 18 + (CGFloat(note.fret - lower) + 0.5) * width / CGFloat(count)
                let y = CGFloat(note.string - 1) * 13 + 15
                context.fill(Path(ellipseIn: CGRect(x: x - 8, y: y - 8, width: 16, height: 16)), with: .color(.mint))
            }.frame(height: 110)
        }
    }
}
