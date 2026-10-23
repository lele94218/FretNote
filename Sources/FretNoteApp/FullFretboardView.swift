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
            let zoom = min(size.width / max(1, camera.width), size.height / max(160, 650 * camera.width / FretboardCamera.overview.width))
            context.translateBy(x: size.width / 2 - camera.center * zoom, y: size.height / 2)
            context.scaleBy(x: zoom, y: zoom)
            drawGuitar(&context, zoom: zoom, visibleHeight: size.height / zoom)
        }.clipped().accessibilityHidden(true)
    }
    private func drawGuitar(_ context: inout GraphicsContext, zoom: CGFloat, visibleHeight: CGFloat) {
        let end = GuitarGeometry.fretX(21) + 22
        // Asymmetric double cutaway, with a full lower bout and a longer bass horn.
        let body = Path { p in
            p.move(to: CGPoint(x: 846, y: -60))
            p.addCurve(to: CGPoint(x: 772, y: -218), control1: CGPoint(x: 950, y: -93), control2: CGPoint(x: 815, y: -154))
            p.addCurve(to: CGPoint(x: 1035, y: -224), control1: CGPoint(x: 699, y: -315), control2: CGPoint(x: 986, y: -201))
            p.addCurve(to: CGPoint(x: 1334, y: -278), control1: CGPoint(x: 1132, y: -235), control2: CGPoint(x: 1238, y: -298))
            p.addCurve(to: CGPoint(x: 1480, y: -15), control1: CGPoint(x: 1464, y: -260), control2: CGPoint(x: 1485, y: -163))
            p.addCurve(to: CGPoint(x: 1320, y: 278), control1: CGPoint(x: 1488, y: 172), control2: CGPoint(x: 1461, y: 275))
            p.addCurve(to: CGPoint(x: 1042, y: 219), control1: CGPoint(x: 1220, y: 282), control2: CGPoint(x: 1153, y: 213))
            p.addCurve(to: CGPoint(x: 690, y: 230), control1: CGPoint(x: 932, y: 210), control2: CGPoint(x: 735, y: 343))
            p.addCurve(to: CGPoint(x: 794, y: 91), control1: CGPoint(x: 664, y: 148), control2: CGPoint(x: 766, y: 238))
            p.addCurve(to: CGPoint(x: 846, y: 60), control1: CGPoint(x: 803, y: 61), control2: CGPoint(x: 831, y: 59))
            p.closeSubpath()
        }
        context.fill(body, with: .linearGradient(Gradient(colors: [Color(white: 0.30), Color(white: 0.055), Color(white: 0.16)]), startPoint: CGPoint(x: 800, y: -280), endPoint: CGPoint(x: 1450, y: 280)))
        context.stroke(body, with: .color(Color(white: 0.5)), lineWidth: 3)
        let guardPlate = Path { p in
            p.move(to: CGPoint(x: 859, y: -71))
            p.addCurve(to: CGPoint(x: 800, y: -215), control1: CGPoint(x: 948, y: -91), control2: CGPoint(x: 839, y: -170))
            p.addCurve(to: CGPoint(x: 1045, y: -200), control1: CGPoint(x: 790, y: -257), control2: CGPoint(x: 965, y: -183))
            p.addCurve(to: CGPoint(x: 1320, y: -237), control1: CGPoint(x: 1150, y: -209), control2: CGPoint(x: 1330, y: -300))
            p.addCurve(to: CGPoint(x: 1250, y: -60), control1: CGPoint(x: 1330, y: -191), control2: CGPoint(x: 1240, y: -159))
            p.addLine(to: CGPoint(x: 1180, y: -60)); p.addLine(to: CGPoint(x: 1180, y: 68))
            p.addCurve(to: CGPoint(x: 1040, y: 123), control1: CGPoint(x: 1180, y: 140), control2: CGPoint(x: 1110, y: 146))
            p.addCurve(to: CGPoint(x: 817, y: 101), control1: CGPoint(x: 900, y: 70), control2: CGPoint(x: 791, y: 157))
            p.addLine(to: CGPoint(x: 825, y: 62)); p.addLine(to: CGPoint(x: 859, y: 62)); p.closeSubpath()
        }
        context.fill(guardPlate, with: .color(Color(white: 0.82)))
        context.stroke(guardPlate, with: .color(Color(white: 0.48)), lineWidth: 3)
        let head = Path { p in
            p.move(to: CGPoint(x: 0, y: -43))
            p.addCurve(to: CGPoint(x: -141, y: -93), control1: CGPoint(x: -91, y: -43), control2: CGPoint(x: -79, y: -133))
            p.addCurve(to: CGPoint(x: -316, y: -10), control1: CGPoint(x: -207, y: -56), control2: CGPoint(x: -302, y: -90))
            p.addCurve(to: CGPoint(x: -269, y: 71), control1: CGPoint(x: -337, y: 46), control2: CGPoint(x: -320, y: 78))
            p.addLine(to: CGPoint(x: -66, y: 49))
            p.addQuadCurve(to: CGPoint(x: 0, y: 43), control: CGPoint(x: -35, y: 40)); p.closeSubpath()
        }
        context.fill(head, with: .linearGradient(Gradient(colors: [Color(white: 0.65), Color(white: 0.42)]), startPoint: CGPoint(x: 0, y: -70), endPoint: CGPoint(x: 0, y: 70)))
        context.stroke(head, with: .color(Color(white: 0.35)), lineWidth: 2)
        for string in 1...6 {
            let x = -280 + CGFloat(string - 1) * 39
            let y = 43 - CGFloat(string - 1) * 4
            context.fill(Path(roundedRect: CGRect(x: x - 5, y: y, width: 10, height: 35), cornerRadius: 3), with: .color(Color(white: 0.65)))
            context.fill(Path(roundedRect: CGRect(x: x - 12, y: y + 26, width: 24, height: 16), cornerRadius: 6), with: .color(Color(white: 0.77)))
            context.fill(Path(ellipseIn: CGRect(x: x - 8, y: y - 19, width: 16, height: 16)), with: .color(Color(white: 0.85)))
        }
        for (x, y) in [(1160.0, -124.0), (1225, -160), (1286, -195)] {
            context.fill(Path(ellipseIn: CGRect(x: x - 18, y: y - 18, width: 36, height: 36)), with: .color(Color(white: 0.92)))
            context.stroke(Path(ellipseIn: CGRect(x: x - 14, y: y - 14, width: 28, height: 28)), with: .color(.gray), lineWidth: 1)
        }
        for (x, y) in [(836.0, -154.0), (1010, -189), (1290, -226), (1130, 117), (835, 105)] {
            context.fill(Path(ellipseIn: CGRect(x: x - 3, y: y - 3, width: 6, height: 6)), with: .color(.gray))
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
        for x in [end + 30, 1000.0, 1110.0] {
            let pickup = CGRect(x: x, y: -57, width: 36, height: 114)
            context.fill(Path(roundedRect: pickup, cornerRadius: 5), with: .color(Color(white: 0.91)))
            context.stroke(Path(roundedRect: pickup.insetBy(dx: 3, dy: 3), cornerRadius: 3), with: .color(Color(white: 0.42)), lineWidth: 1)
            for s in 1...6 {
                context.fill(Path(ellipseIn: CGRect(x: x + 12, y: GuitarGeometry.stringY(s, x: x) - 3, width: 6, height: 6)), with: .color(Color(white: 0.65)))
            }
        }
        context.fill(Path(roundedRect: CGRect(x: 1185, y: -56, width: 29, height: 112), cornerRadius: 3), with: .color(Color(white: 0.57)))
        for string in 1...6 {
            let y = GuitarGeometry.stringY(string, x: 1200)
            let saddle = Path(roundedRect: CGRect(x: 1189, y: y - 6, width: 19, height: 12), cornerRadius: 2)
            context.fill(saddle, with: .color(Color(white: 0.82)))
            context.stroke(saddle, with: .color(Color(white: 0.35)), lineWidth: 1)
        }
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
            line.move(to: CGPoint(x: -280 + CGFloat(string - 1) * 39, y: 32 - CGFloat(string - 1) * 4))
            line.addLine(to: CGPoint(x: -40, y: GuitarGeometry.stringY(string, x: 0)))
            line.addLine(to: CGPoint(x: 0, y: GuitarGeometry.stringY(string, x: 0)))
            line.addLine(to: CGPoint(x: 1200, y: GuitarGeometry.stringY(string, x: 1200)))
            context.stroke(line, with: .color(.black.opacity(0.8)), lineWidth: gauge + 1.3)
            context.stroke(line, with: .color(Color(white: string > 3 ? 0.65 : 0.87)), lineWidth: gauge)
            context.stroke(line, with: .color(.white.opacity(0.7)), lineWidth: max(0.3, gauge * 0.24))
        }
        // Marker diameter is bounded by physical string spacing, even in overview.
        // Text belongs outside the neck; it must never cover adjacent strings.
        for index in min(notes.count, max(0, current - 2))..<min(notes.count, max(0, current + 3)) {
            let note = notes[index]
            guard (0...21).contains(note.fret), (1...6).contains(note.string) else { continue }
            let x = GuitarGeometry.noteX(note.fret), y = GuitarGeometry.stringY(note.string, x: x)
            let radius = GuitarGeometry.markerRadius(x: x, zoom: zoom) * (index == current ? 1 : 0.65)
            if index == current {
                var segment = Path()
                let left = max(0, x - 30), right = max(0, x + 30)
                segment.move(to: CGPoint(x: left, y: GuitarGeometry.stringY(note.string, x: left)))
                segment.addLine(to: CGPoint(x: right, y: GuitarGeometry.stringY(note.string, x: right)))
                context.stroke(segment, with: .color(.white), lineWidth: 2 / zoom)
                let labelY = max(-100 - 18 / zoom, -visibleHeight / 2 + 16 / zoom)
                var leader = Path(); leader.move(to: CGPoint(x: x, y: y - radius - 1))
                leader.addLine(to: CGPoint(x: x, y: labelY + 13 / zoom))
                context.stroke(leader, with: .color(dark ? .white.opacity(0.55) : .gray), style: StrokeStyle(lineWidth: 0.7 / zoom, dash: [2 / zoom, 3 / zoom]))
                let plate = CGRect(x: x - 27 / zoom, y: labelY - 12 / zoom, width: 54 / zoom, height: 24 / zoom)
                context.fill(Path(roundedRect: plate, cornerRadius: 3 / zoom), with: .color(dark ? .white : .black))
                context.draw(Text(note.fullName).font(.editorial(size: 13 / zoom, weight: .medium)).foregroundColor(dark ? .black : .white), at: CGPoint(x: x, y: labelY))
            }
            let dot = Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
            context.fill(dot, with: .color(index < current ? .white.opacity(0.35) : .white))
            context.stroke(dot, with: .color(.black), lineWidth: radius * 0.3)
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
