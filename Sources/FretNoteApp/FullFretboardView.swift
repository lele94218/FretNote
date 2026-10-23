import SwiftUI
import FretNoteCore

/// A photo-traced neck in one coordinate system. Only the camera moves.
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
            let zoom = min(size.width / max(1, camera.width), size.height / max(210, 300 * camera.width / FretboardCamera.overview.width))
            context.translateBy(x: size.width / 2 - camera.center * zoom, y: size.height / 2)
            context.scaleBy(x: zoom, y: zoom)
            drawGuitar(&context, zoom: zoom, visibleHeight: size.height / zoom)
        }.clipped().accessibilityHidden(true)
    }
    private func drawGuitar(_ context: inout GraphicsContext, zoom: CGFloat, visibleHeight: CGFloat) {
        let accent = Color(red: 0.20, green: 0.85, blue: 0.96)
        let upcomingAccent = Color(red: 1.0, green: 0.70, blue: 0.25)
        for layer in NeckArtwork.bodyLayers {
            context.fill(layer.path, with: .color(layer.color))
        }
        context.drawLayer { artwork in
            artwork.clip(to: NeckArtwork.outline)
            for layer in NeckArtwork.layers {
                artwork.fill(layer.path, with: .color(layer.color))
            }
        }
        // Metallic posts sit in the photographed tuning holes.
        for string in 1...6 {
            let post = NeckArtwork.tuningPost(string)
            let ring = CGRect(x: post.x - 8, y: post.y - 8, width: 16, height: 16)
            context.fill(Path(ellipseIn: ring), with: .linearGradient(Gradient(colors: [.gray, .white, .gray]), startPoint: CGPoint(x: ring.minX, y: ring.minY), endPoint: CGPoint(x: ring.maxX, y: ring.maxY)))
            context.fill(Path(ellipseIn: ring.insetBy(dx: 4, dy: 4)), with: .color(Color(white: 0.25)))
        }
        for fret in 1...21 where zoom >= 1 || [1, 3, 5, 7, 9, 12, 15, 17, 19, 21].contains(fret) {
            if fret >= 12 {
                let rect = CGRect(x: GuitarGeometry.noteX(fret) - 9 / zoom, y: 85 + 10 / zoom, width: 18 / zoom, height: 14 / zoom)
                context.fill(Path(roundedRect: rect, cornerRadius: 2 / zoom), with: .color(dark ? Color(white: 0.07) : .white))
            }
            context.draw(Text("\(fret)").font(.editorial(size: 10 / zoom)).foregroundColor(dark ? .white.opacity(0.7) : .black.opacity(0.65)), at: CGPoint(x: GuitarGeometry.noteX(fret), y: 85 + 17 / zoom))
        }
        for string in 1...6 {
            let gauge: CGFloat = [0.55, 0.75, 1.05, 1.5, 2.0, 2.6][string - 1]
            var line = Path()
            line.move(to: NeckArtwork.tuningPost(string))
            line.addLine(to: CGPoint(x: -40, y: GuitarGeometry.stringY(string, x: 0)))
            line.addLine(to: CGPoint(x: 0, y: GuitarGeometry.stringY(string, x: 0)))
            line.addLine(to: CGPoint(x: GuitarGeometry.scaleLength, y: GuitarGeometry.stringY(string, x: GuitarGeometry.scaleLength)))
            context.stroke(line, with: .color(.black.opacity(0.8)), lineWidth: gauge + 1.3)
            context.stroke(line, with: .color(Color(white: string > 3 ? 0.65 : 0.87)), lineWidth: gauge)
            context.stroke(line, with: .color(.white.opacity(0.7)), lineWidth: max(0.3, gauge * 0.24))
            if notes.indices.contains(current), notes[current].string == string,
               (0...21).contains(notes[current].fret) {
                let stop = GuitarGeometry.fretX(notes[current].fret)
                var muted = Path()
                muted.move(to: CGPoint(x: 0, y: GuitarGeometry.stringY(string, x: 0)))
                muted.addLine(to: CGPoint(x: stop, y: GuitarGeometry.stringY(string, x: stop)))
                context.stroke(muted, with: .color(accent.opacity(0.45)), lineWidth: 1.5 / zoom)
                // The sounding length runs from the fretted contact to the bridge.
                var sounding = Path()
                sounding.move(to: CGPoint(x: stop, y: GuitarGeometry.stringY(string, x: stop)))
                sounding.addLine(to: CGPoint(x: GuitarGeometry.scaleLength, y: GuitarGeometry.stringY(string, x: GuitarGeometry.scaleLength)))
                context.stroke(sounding, with: .color(accent.opacity(0.18)), lineWidth: 4 / zoom)
                context.stroke(sounding, with: .color(accent), lineWidth: 2 / zoom)
            }
        }
        // Marker diameter is bounded by physical string spacing, even in overview.
        // Text belongs outside the neck; it must never cover adjacent strings.
        for index in min(notes.count, max(0, current - 2))..<min(notes.count, max(0, current + 3)) {
            let note = notes[index]
            guard (0...21).contains(note.fret), (1...6).contains(note.string) else { continue }
            let x = GuitarGeometry.noteX(note.fret), y = GuitarGeometry.stringY(note.string, x: x)
            let radius = GuitarGeometry.markerRadius(x: x, zoom: zoom) * (index == current ? 1 : (index == current + 1 ? 0.8 : 0.65))
            if index == current {
                let labelY = max(-100 - 18 / zoom, -visibleHeight / 2 + 22 / zoom)
                var leader = Path(); leader.move(to: CGPoint(x: x, y: y - radius - 1))
                leader.addLine(to: CGPoint(x: x, y: labelY + 17 / zoom))
                context.stroke(leader, with: .color(accent.opacity(0.85)), style: StrokeStyle(lineWidth: 1 / zoom, dash: [2 / zoom, 3 / zoom]))
                let plate = CGRect(x: x - 34 / zoom, y: labelY - 16 / zoom, width: 68 / zoom, height: 32 / zoom)
                context.fill(Path(roundedRect: plate, cornerRadius: 3 / zoom), with: .color(accent))
                context.draw(Text(note.fullName).font(.editorial(size: 16 / zoom, weight: .semibold)).foregroundColor(.black), at: CGPoint(x: x, y: labelY))
            }
            let dot = Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
            context.fill(dot, with: .color(index == current ? accent : (index == current + 1 ? upcomingAccent : (index < current ? .white.opacity(0.35) : .white))))
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
    var framingNotes: [GuitarNote]? = nil
    var prompt: String? = nil
    @State private var step = 0
    @State private var playing = false
    @State private var isFraming = false
    @State private var follow = true
    @State private var camera = FretboardCamera.overview
    private var index: Int { live ? current : step }
    private var palette: AppPalette { AppPalette(scheme: scheme) }
    private var animation: Animation? { reduceMotion ? nil : .easeInOut(duration: 0.55) }
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(L("全指板")).font(.editorial(size: 20 * scale))
                Spacer()
                Button(L("完整琴颈")) { playing = false; follow = false; camera = .overview }
                Button(L("自动取景")) { playing = false; follow = true; updateCamera() }
                    .buttonStyle(EditorialButtonStyle(prominent: follow))
                Button(L("完成")) { dismiss() }.keyboardShortcut(.cancelAction)
            }
            HStack {
                Text(L(live ? "跟随练习进度 · 显示参考弦位" : "动画演示 · 不计入学习记录"))
                Spacer()
                if isFraming {
                    Text(L("准备下一个音…"))
                } else if let prompt {
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
                        playing.toggle()
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
            .onChange(of: framingNotes) { _ in if live { updateCamera() } }
            .onChange(of: notes) { _ in if live && framingNotes == nil { updateCamera() } }
            .onAppear { if live { updateCamera() } }
            .task(id: playing) {
                guard playing else { isFraming = false; return }
                // A note is not activated until its camera has finished moving.
                guard await prepareFrame(at: step, initial: true) else { return }
                while !Task.isCancelled {
                    do { try await Task.sleep(nanoseconds: 1_200_000_000) } catch { return }
                    guard !Task.isCancelled else { return }
                    guard step + 1 < notes.count else { playing = false; return }
                    let next = step + 1
                    guard await prepareFrame(at: next) else { return }
                    step = next
                }
            }
    }
    private func updateCamera() {
        guard follow else { return }
        // Live exercises are framed as a whole before playing, never chased
        // reactively after each detected pitch. Manual scrubbing also settles at once.
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            camera = live ? .fitting(framingNotes ?? notes) : .following(notes, index: index)
            isFraming = false
        }
    }
    private func prepareFrame(at next: Int, initial: Bool = false) async -> Bool {
        guard follow else { return !Task.isCancelled }
        let target = initial ? FretboardCamera.following(notes, index: next)
            : FretboardCamera.preparing(notes, index: next, from: camera)
        guard target != camera else { return !Task.isCancelled }
        isFraming = true
        camera = target
        if !reduceMotion {
            // Longer than the 0.55 s camera animation, including a settling margin.
            do { try await Task.sleep(nanoseconds: 700_000_000) }
            catch { return false }
        }
        guard !Task.isCancelled else { return false }
        isFraming = false
        return true
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
                          framingNotes: practice.active ? practice.notes : nil,
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
                          framingNotes: drill.active ? all : nil,
                          prompt: drill.active ? all.map(\.name).joined(separator: " · ") : nil)
    }
}
