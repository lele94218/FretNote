import SwiftUI
import FretNoteCore

/// A complete instrument in one coordinate system. Only the camera moves.
struct GuitarInstrumentCanvas: View, Animatable {
    var camera: FretboardCamera
    var notes: [GuitarNote]
    var current: Int
    var dark: Bool
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(camera.center, camera.width) }
        set { camera = FretboardCamera(center: newValue.first, width: newValue.second) }
    }
    var body: some View {
        Canvas { context, size in
            guard size.width > 0, size.height > 0 else { return }
            let zoom = min(size.width / max(1, camera.width), size.height / max(160, 340 * camera.width / FretboardCamera.overview.width))
            context.translateBy(x: size.width / 2 - camera.center * zoom, y: size.height / 2)
            context.scaleBy(x: zoom, y: zoom)
            drawGuitar(&context, zoom: zoom)
        }.clipped().accessibilityHidden(true)
    }
    private func drawGuitar(_ context: inout GraphicsContext, zoom: CGFloat) {
        let end = GuitarGeometry.fretX(21) + 22
        let body = Path { p in
            p.move(to: CGPoint(x: end - 28, y: -61))
            p.addCurve(to: CGPoint(x: 876, y: -148), control1: CGPoint(x: 795, y: -180), control2: CGPoint(x: 815, y: -178))
            p.addCurve(to: CGPoint(x: 1130, y: -151), control1: CGPoint(x: 1000, y: -87), control2: CGPoint(x: 1050, y: -156))
            p.addCurve(to: CGPoint(x: 1330, y: 0), control1: CGPoint(x: 1298, y: -170), control2: CGPoint(x: 1328, y: -102))
            p.addCurve(to: CGPoint(x: 1130, y: 151), control1: CGPoint(x: 1328, y: 102), control2: CGPoint(x: 1298, y: 170))
            p.addCurve(to: CGPoint(x: 876, y: 148), control1: CGPoint(x: 1050, y: 156), control2: CGPoint(x: 1000, y: 87))
            p.addCurve(to: CGPoint(x: end - 28, y: 61), control1: CGPoint(x: 815, y: 178), control2: CGPoint(x: 795, y: 180))
            p.closeSubpath()
        }
        context.fill(body, with: .linearGradient(Gradient(colors: [Color(white: 0.29), Color(white: 0.09), Color(white: 0.2)]), startPoint: CGPoint(x: 800, y: -160), endPoint: CGPoint(x: 1310, y: 160)))
        context.stroke(body, with: .color(Color(white: 0.46)), lineWidth: 2)
        let head = Path { p in
            p.move(to: CGPoint(x: 0, y: -41)); p.addLine(to: CGPoint(x: -62, y: -44))
            p.addQuadCurve(to: CGPoint(x: -198, y: -67), control: CGPoint(x: -115, y: -96))
            p.addQuadCurve(to: CGPoint(x: -210, y: 52), control: CGPoint(x: -240, y: -20))
            p.addLine(to: CGPoint(x: -62, y: 44)); p.addLine(to: CGPoint(x: 0, y: 41)); p.closeSubpath()
        }
        context.fill(head, with: .linearGradient(Gradient(colors: [Color(white: 0.26), Color(white: 0.12)]), startPoint: CGPoint(x: 0, y: -70), endPoint: CGPoint(x: 0, y: 70)))
        context.stroke(head, with: .color(Color(white: 0.48)), lineWidth: 2)
        for i in 0..<6 {
            let x = -186 + CGFloat(i % 3) * 47
            let y: CGFloat = i < 3 ? -62 : 57
            let peg = CGRect(x: x - 10, y: y - 10, width: 20, height: 20)
            context.fill(Path(roundedRect: peg, cornerRadius: 6), with: .color(Color(white: 0.65)))
            context.fill(Path(ellipseIn: CGRect(x: x - 4, y: y - (y < 0 ? -22 : 22) - 4, width: 8, height: 8)), with: .color(Color(white: 0.84)))
        }
        let neck = Path { p in
            p.move(to: CGPoint(x: 0, y: -43)); p.addLine(to: CGPoint(x: end, y: -61))
            p.addLine(to: CGPoint(x: end, y: 61)); p.addLine(to: CGPoint(x: 0, y: 43)); p.closeSubpath()
        }
        context.fill(neck, with: .linearGradient(Gradient(colors: [Color(red: 0.19, green: 0.17, blue: 0.15), Color(white: 0.10), Color(red: 0.17, green: 0.15, blue: 0.13)]), startPoint: CGPoint(x: 0, y: -60), endPoint: CGPoint(x: 0, y: 60)))
        context.stroke(neck, with: .color(Color(white: 0.55)), lineWidth: 2)
        // Fine deterministic grain stays attached to the neck during animation.
        for i in 0..<20 {
            let y = CGFloat(i - 10) * 4
            var grain = Path(); grain.move(to: CGPoint(x: 4, y: y))
            grain.addQuadCurve(to: CGPoint(x: end - 3, y: y * 1.35), control: CGPoint(x: end * 0.6, y: y + CGFloat(i % 3) * 2))
            context.stroke(grain, with: .color(.white.opacity(0.035)), lineWidth: 0.5)
        }
        for x in [end + 26, 1105.0] {
            let pickup = CGRect(x: x, y: -57, width: 36, height: 114)
            context.fill(Path(roundedRect: pickup, cornerRadius: 5), with: .color(Color(white: 0.06)))
            context.stroke(Path(roundedRect: pickup.insetBy(dx: 3, dy: 3), cornerRadius: 3), with: .color(Color(white: 0.42)), lineWidth: 1)
            for s in 1...6 {
                context.fill(Path(ellipseIn: CGRect(x: x + 12, y: GuitarGeometry.stringY(s, x: x) - 3, width: 6, height: 6)), with: .color(Color(white: 0.65)))
            }
        }
        context.fill(Path(roundedRect: CGRect(x: 1185, y: -56, width: 29, height: 112), cornerRadius: 3), with: .color(Color(white: 0.57)))
        for fret in 0...21 {
            let x = GuitarGeometry.fretX(fret)
            let half = 43 + x / end * 18
            let wire = CGRect(x: x - (fret == 0 ? 3 : 1.5), y: -half, width: fret == 0 ? 6 : 3, height: half * 2)
            context.fill(Path(roundedRect: wire, cornerRadius: 1), with: .linearGradient(Gradient(colors: [.gray, .white.opacity(0.9), .gray]), startPoint: CGPoint(x: x - 2, y: 0), endPoint: CGPoint(x: x + 2, y: 0)))
            if [3, 5, 7, 9, 12, 15, 17, 19, 21].contains(fret) {
                for y: CGFloat in fret == 12 ? [-21, 21] : [0] {
                    context.fill(Path(ellipseIn: CGRect(x: GuitarGeometry.noteX(fret) - 5, y: y - 5, width: 10, height: 10)), with: .color(Color(white: 0.75)))
                }
            }
            if fret > 0 && (zoom >= 1 || [1, 3, 5, 7, 9, 12, 15, 17, 19, 21].contains(fret)) {
                if fret >= 19 {
                    context.fill(Path(roundedRect: CGRect(x: GuitarGeometry.noteX(fret) - 9 / zoom, y: half + 10 / zoom, width: 18 / zoom, height: 14 / zoom), cornerRadius: 2 / zoom), with: .color(dark ? Color(white: 0.07) : .white))
                }
                context.draw(Text("\(fret)").font(.editorial(size: 10 / zoom)).foregroundColor(dark ? .white.opacity(0.7) : .black.opacity(0.65)), at: CGPoint(x: GuitarGeometry.noteX(fret), y: half + 17 / zoom))
            }
        }
        for string in 1...6 {
            let gauge: CGFloat = [0.55, 0.75, 1.05, 1.5, 2.0, 2.6][string - 1]
            var line = Path()
            line.move(to: CGPoint(x: -190 + CGFloat((string - 1) % 3) * 47, y: string < 4 ? -40 : 35))
            line.addLine(to: CGPoint(x: 0, y: GuitarGeometry.stringY(string, x: 0)))
            line.addLine(to: CGPoint(x: 1200, y: GuitarGeometry.stringY(string, x: 1200)))
            context.stroke(line, with: .color(.black.opacity(0.8)), lineWidth: gauge + 1.3)
            context.stroke(line, with: .color(Color(white: string > 3 ? 0.65 : 0.87)), lineWidth: gauge)
            context.stroke(line, with: .color(.white.opacity(0.7)), lineWidth: max(0.3, gauge * 0.24))
        }
        // Only a short trail and look-ahead are shown, keeping the neck readable.
        for index in min(notes.count, max(0, current - 2))..<min(notes.count, max(0, current + 3)) {
            let note = notes[index]
            guard (0...21).contains(note.fret), (1...6).contains(note.string) else { continue }
            let x = GuitarGeometry.noteX(note.fret), y = GuitarGeometry.stringY(note.string, x: x)
            let radius = (index == current ? 12.0 : 8.0) / zoom
            let dot = Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
            context.fill(dot, with: .color(index < current ? .white.opacity(0.25) : .white))
            context.stroke(dot, with: .color(.black), lineWidth: (index == current ? 2 : 1) / zoom)
            if index > current {
                context.draw(Text("\(index - current + 1)").font(.editorial(size: 9 / zoom)).foregroundColor(.black), at: CGPoint(x: x, y: y))
            }
            if index == current {
                context.stroke(Path(ellipseIn: CGRect(x: x - radius - 4 / zoom, y: y - radius - 4 / zoom, width: radius * 2 + 8 / zoom, height: radius * 2 + 8 / zoom)), with: .color(.white), lineWidth: 1 / zoom)
                context.draw(Text(note.name).font(.editorial(size: 11 / zoom, weight: .medium)).foregroundColor(.black), at: CGPoint(x: x, y: y))
            }
        }
    }
}

struct FullFretboardView: View, Localizable {
    @Environment(\.appLanguage) var language
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.interfaceScale) private var scale
    var notes: [GuitarNote] = GuitarGeometry.demo
    var current: Int = 0
    var live = false
    var prompt: String? = nil
    @State private var step = 0
    @State private var playing = false
    @State private var follow = true
    @State private var camera = FretboardCamera.overview
    private var index: Int { live ? current : step }
    private var palette: AppPalette { AppPalette(scheme: scheme) }
    private var animation: Animation? { reduceMotion ? nil : .easeInOut(duration: 0.7) }
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(L("全指板")).font(.editorial(size: 20 * scale))
                Spacer()
                Button(L("完整琴颈")) { follow = false; camera = .overview }
                Button(L("自动取景")) { follow = true; updateCamera() }
                    .buttonStyle(EditorialButtonStyle(prominent: follow))
                Button(L("完成")) { dismiss() }.keyboardShortcut(.cancelAction)
            }
            HStack {
                Text(L(live ? "跟随练习进度 · 显示参考弦位" : "动画演示 · 不计入学习记录"))
                Spacer()
                if let prompt {
                    Text(prompt).monospacedDigit()
                } else if notes.indices.contains(index) {
                    let note = notes[index]
                    Text("\(note.fullName) · " + L("第 \(note.string) 弦") + " · " + (note.fret == 0 ? L("空弦") : L("第 \(note.fret) 品")))
                        .monospacedDigit()
                }
            }.foregroundStyle(palette.muted)
            GuitarInstrumentCanvas(camera: camera, notes: notes, current: index, dark: scheme == .dark)
                .animation(animation, value: camera)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            overview
                .frame(height: 48)
            if !live {
                HStack(spacing: 16) {
                    Button { playing = false; step = max(0, step - 1); updateCamera() } label: { Image(systemName: "backward.end") }.accessibilityLabel(L("上一个音")).keyboardShortcut(.leftArrow, modifiers: [])
                    Button(L(playing ? "暂停演示" : "播放演示")) {
                        if step == notes.count - 1 { step = 0 }
                        playing.toggle(); updateCamera()
                    }.buttonStyle(EditorialButtonStyle(prominent: true))
                    Button { playing = false; step = min(max(0, notes.count - 1), step + 1); updateCamera() } label: { Image(systemName: "forward.end") }.accessibilityLabel(L("下一个音")).keyboardShortcut(.rightArrow, modifiers: [])
                    Slider(value: Binding(get: { Double(step) }, set: { playing = false; step = Int($0); updateCamera() }), in: 0...Double(max(1, notes.count - 1)), step: 1)
                        .accessibilityLabel(L("演示进度"))
                    Text("\(notes.isEmpty ? 0 : index + 1) / \(notes.count)").monospacedDigit()
                }
            }
        }.padding(24)
            .font(.editorial(size: 12 * scale))
            .foregroundStyle(palette.ink).background(palette.background)
            .buttonStyle(EditorialButtonStyle())
            .frame(minWidth: 900, idealWidth: 960, minHeight: 560, idealHeight: 620)
            .onChange(of: current) { _ in if live { updateCamera() } }
            .onChange(of: notes) { _ in if live { updateCamera() } }
            .onAppear { if live { updateCamera() } }
            .task(id: playing) {
                guard playing else { return }
                while !Task.isCancelled {
                    do { try await Task.sleep(nanoseconds: 1_200_000_000) } catch { return }
                    guard !Task.isCancelled else { return }
                    if step + 1 < notes.count { step += 1; updateCamera() }
                    else { playing = false; camera = .overview; return }
                }
            }
    }
    private func updateCamera() {
        if follow { camera = .following(notes, index: index) }
    }
    private var overview: some View {
        GeometryReader { space in
            let end = GuitarGeometry.fretX(21)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2).fill(palette.selection)
                ForEach(0...21, id: \.self) { fret in
                    Rectangle().fill(palette.rule).frame(width: 1).offset(x: GuitarGeometry.fretX(fret) / end * space.size.width)
                }
                let left = max(0, camera.center - camera.width / 2)
                let right = min(end, camera.center + camera.width / 2)
                Rectangle().strokeBorder(palette.ink, lineWidth: 1.5)
                    .frame(width: max(0, right - left) / end * space.size.width)
                    .offset(x: left / end * space.size.width)
                    .animation(animation, value: camera)
                HStack { Text("0"); Spacer(); Text("21") }.padding(6).font(.editorial(size: 11))
            }.contentShape(Rectangle())
                .onTapGesture { position in
                    let target = max(0, min(end, position.x / max(1, space.size.width) * end))
                    follow = false
                    camera = FretboardCamera(center: target, width: 400)
                }
                .accessibilityLabel(L("全指板概览"))
        }
    }
}

/// The sheet observes live stores instead of capturing a stale note array.
struct PracticeFretboardSheet: View {
    @ObservedObject var practice: PracticeStore
    var body: some View {
        let shown = Array(practice.notes.prefix(practice.index)) + (practice.hint ? practice.target.map { [$0] } ?? [] : [])
        FullFretboardView(notes: practice.active ? shown : GuitarGeometry.demo,
                          current: max(0, shown.count - 1), live: practice.active,
                          prompt: practice.active ? practice.target.map { $0.fullName + " · \(practice.answered) / 20" } : nil)
    }
}
struct ShapeFretboardSheet: View {
    @ObservedObject var drill: ShapePracticeStore
    var body: some View {
        let all = drill.question?.shape.tones.map(\.note) ?? []
        let shown = drill.revealed || drill.completed ? all : Array(all.prefix(drill.noteIndex))
        FullFretboardView(notes: drill.active ? shown : GuitarGeometry.demo,
                          current: min(max(0, shown.count - 1), drill.noteIndex), live: drill.active,
                          prompt: drill.active ? all.map(\.name).joined(separator: " · ") : nil)
    }
}
