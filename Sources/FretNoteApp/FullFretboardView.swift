import SwiftUI
import FretNoteCore
import UniformTypeIdentifiers

/// A photo-traced neck in one coordinate system. Only the camera moves.
struct GuitarInstrumentCanvas: View, Animatable {
    var camera: FretboardCamera
    var notes: [GuitarNote]
    var current: Int
    var dark: Bool
    var activePositions: [GuitarNote]? = nil
    var upcomingPositions: [GuitarNote]? = nil
    var barPositions: [GuitarNote] = []
    var bends: [ScoreBendDisplay] = []
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
        for layer in NeckArtwork.bodyLayers {
            context.fill(layer.path, with: .color(layer.color))
        }
        context.drawLayer { artwork in
            artwork.clip(to: NeckArtwork.outline)
            for layer in NeckArtwork.layers {
                artwork.fill(layer.path, with: .color(layer.color))
            }
        }
        // Inlays are geometric circles, never irregular photo-traced polygons.
        for fret in [3, 5, 7, 9, 12, 15, 17, 19, 21] {
            for y: CGFloat in fret == 12 ? [-24, 24] : [0] {
                let circle = CGRect(x: GuitarGeometry.noteX(fret) - 6, y: y - 6, width: 12, height: 12)
                context.fill(Path(ellipseIn: circle), with: .color(Color(red: 0.87, green: 0.84, blue: 0.72)))
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
        let active = activePositions ?? (notes.indices.contains(current) ? [notes[current]] : [])
        for string in 1...6 {
            let accent = GuitarStringPalette.color(string)
            let gauge: CGFloat = [0.55, 0.75, 1.05, 1.5, 2.0, 2.6][string - 1]
            let bend = bends.first { $0.position.string == string && $0.position.fret > 0 }
            let contactX = bend.map { GuitarGeometry.noteX($0.position.fret) }
            func point(_ x: CGFloat) -> CGPoint {
                CGPoint(x: x, y: GuitarGeometry.stringY(string, x: x) + (bend?.stringDisplacement(at: x) ?? 0))
            }
            var line = Path()
            line.move(to: NeckArtwork.tuningPost(string))
            line.addLine(to: CGPoint(x: -40, y: GuitarGeometry.stringY(string, x: 0)))
            line.addLine(to: CGPoint(x: 0, y: GuitarGeometry.stringY(string, x: 0)))
            if let contactX { line.addLine(to: point(contactX)) }
            line.addLine(to: point(GuitarGeometry.scaleLength))
            context.stroke(line, with: .color(.black.opacity(0.8)), lineWidth: gauge + 1.3)
            context.stroke(line, with: .color(accent.opacity(0.8)), lineWidth: max(gauge, 1 / zoom))
            context.stroke(line, with: .color(.white.opacity(0.3)), lineWidth: max(0.3, gauge * 0.24))
            if let note = active.first(where: { $0.string == string && (0...21).contains($0.fret) }) {
                let stop = contactX ?? GuitarGeometry.fretX(note.fret)
                var muted = Path()
                muted.move(to: CGPoint(x: 0, y: GuitarGeometry.stringY(string, x: 0)))
                muted.addLine(to: point(stop))
                context.stroke(muted, with: .color(accent.opacity(0.45)), lineWidth: 1.5 / zoom)
                // The sounding length runs from the fretted contact to the bridge.
                var sounding = Path()
                sounding.move(to: point(stop))
                sounding.addLine(to: point(GuitarGeometry.scaleLength))
                context.stroke(sounding, with: .color(accent.opacity(0.18)), lineWidth: 4 / zoom)
                context.stroke(sounding, with: .color(accent), lineWidth: 2 / zoom)
            }
        }
        // Marker diameter is bounded by physical string spacing, even in overview.
        // Text belongs outside the neck; it must never cover adjacent strings.
        let markers: [(GuitarNote, Int)] = activePositions.map { active in
            let upcoming = (upcomingPositions ?? []).filter { !active.contains($0) }
            let background = barPositions.filter { !active.contains($0) && !upcoming.contains($0) }
            return background.map { ($0, 2) } + upcoming.map { ($0, 1) } + active.map { ($0, 0) }
        } ?? (min(notes.count, max(0, current - 2))..<min(notes.count, max(0, current + 3))).map { (notes[$0], $0 - current) }
        for (note, relative) in markers {
            let accent = GuitarStringPalette.color(note.string)
            guard (0...21).contains(note.fret), (1...6).contains(note.string) else { continue }
            let x = GuitarGeometry.noteX(note.fret)
            let displacement = relative == 0 ? bends.first(where: { $0.position == note })?.stringDisplacement(at: x) ?? 0 : 0
            let y = GuitarGeometry.stringY(note.string, x: x) + displacement
            let radius = GuitarGeometry.markerRadius(x: x, zoom: zoom) * (relative == 0 ? 1 : (relative == 1 ? 0.8 : 0.65))
            if relative == 0 && active.count == 1 && !bends.contains(where: { $0.position == note }) {
                let labelY = max(-100 - 18 / zoom, -visibleHeight / 2 + 22 / zoom)
                var leader = Path(); leader.move(to: CGPoint(x: x, y: y - radius - 1))
                leader.addLine(to: CGPoint(x: x, y: labelY + 17 / zoom))
                context.stroke(leader, with: .color(accent.opacity(0.85)), style: StrokeStyle(lineWidth: 1 / zoom, dash: [2 / zoom, 3 / zoom]))
                let plate = CGRect(x: x - 34 / zoom, y: labelY - 16 / zoom, width: 68 / zoom, height: 32 / zoom)
                context.fill(Path(roundedRect: plate, cornerRadius: 3 / zoom), with: .color(accent))
                context.draw(Text(note.fullName).font(.editorial(size: 16 / zoom, weight: .semibold)).foregroundColor(.black), at: CGPoint(x: x, y: labelY))
            }
            let dot = Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
            // String color identifies pitch lane; fill/rings identify playback state.
            if relative == 1 {
                context.fill(dot, with: .color(.black.opacity(0.85)))
                context.stroke(dot, with: .color(accent), lineWidth: radius * 0.45)
            } else {
                context.fill(dot, with: .color(accent.opacity(relative == 0 ? 1 : 0.55)))
                context.stroke(dot, with: .color(.black), lineWidth: radius * 0.3)
                if relative == 0 {
                    context.stroke(Path(ellipseIn: CGRect(x: x - radius - 2 / zoom, y: y - radius - 2 / zoom,
                                                        width: radius * 2 + 4 / zoom, height: radius * 2 + 4 / zoom)),
                                   with: .color(.white), lineWidth: 1.5 / zoom)
                }
            }
        }
        // The fretting dot follows its displaced string while keeping the same fret.
        // Instructions stay outside the neck and follow the audio clock.
        for (index, bend) in bends.enumerated() {
            let accent = GuitarStringPalette.color(bend.position.string)
            let note = bend.position
            let x = GuitarGeometry.noteX(note.fret)
            let y = GuitarGeometry.stringY(note.string, x: x) + bend.stringDisplacement(at: x)
            let labelX = camera.center + (CGFloat(index) - CGFloat(bends.count - 1) / 2) * 156 / zoom
            let labelY = max(-110 - 22 / zoom, -visibleHeight / 2 + 34 / zoom)
            let rect = CGRect(x: labelX - 72 / zoom, y: labelY - 29 / zoom, width: 144 / zoom, height: 58 / zoom)
            var leader = Path()
            leader.move(to: CGPoint(x: x, y: y - GuitarGeometry.markerRadius(x: x, zoom: zoom) - 2 / zoom))
            leader.addLine(to: CGPoint(x: labelX, y: rect.maxY))
            context.stroke(leader, with: .color(accent.opacity(0.7)), style: StrokeStyle(lineWidth: 1 / zoom, dash: [2 / zoom, 3 / zoom]))
            context.fill(Path(roundedRect: rect, cornerRadius: 3 / zoom), with: .color(accent))
            context.draw(Text(bend.pitchLabel).font(.editorial(size: 13 / zoom, weight: .semibold)).foregroundColor(.black), at: CGPoint(x: labelX, y: labelY - 15 / zoom))
            context.draw(Text((bend.releasing ? "↓ " : "↑ ") + bend.amountLabel).font(.editorial(size: 16 / zoom, weight: .semibold)).foregroundColor(.black), at: CGPoint(x: labelX, y: labelY + 3 / zoom))
            let meter = CGRect(x: labelX - 60 / zoom, y: labelY + 19 / zoom, width: 120 / zoom, height: 3 / zoom)
            context.fill(Path(meter), with: .color(.black.opacity(0.2)))
            context.fill(Path(CGRect(x: meter.minX, y: meter.minY, width: meter.width * bend.progress, height: meter.height)), with: .color(.black))
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
    var embedded = false
    @StateObject var workspace = GuitarProWorkspace(file: nil)
    @State private var importing = false
    @State private var loading = false
    @State private var importError: String?
    @State private var step = 0
    @State private var playing = false
    @State private var follow = true
    @State private var camera = FretboardCamera.overview
    private var index: Int { live ? current : step }
    private var palette: AppPalette { AppPalette(scheme: scheme) }
    private var animation: Animation? { reduceMotion ? nil : .easeInOut(duration: FretboardPlaybackTimeline.cameraAnimation) }
    var body: some View {
        VStack(spacing: 0) {
            if !live && !workspace.documents.isEmpty { documentTabs }
            if !live, let document = workspace.selected {
                GuitarProPlaybackView(score: document.score, embedded: embedded) { workspace.select(nil) }
                    .id(document.id)
            } else { demoBody }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: ["gp3", "gp4", "gp5", "gpx", "gp"].compactMap { UTType(filenameExtension: $0) }, allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            playing = false
            loading = true
            Task {
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() }; loading = false }
                do {
                    let score = try await Task.detached(priority: .userInitiated) { try GuitarProScore.load(url) }.value
                    try workspace.add(score: score, sourceName: url.lastPathComponent)
                }
                catch { importError = error.localizedDescription }
            }
        }
        .alert(L("无法导入"), isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button(L("好")) { importError = nil }
        } message: { Text(L(importError ?? "")) }
        .onChange(of: workspace.error) { value in if let value { importError = value; workspace.error = nil } }
        .onAppear { if let error = workspace.error { importError = error; workspace.error = nil } }
    }
    private var documentTabs: some View {
        HStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(workspace.documents) { document in
                        HStack(spacing: 8) {
                            Button { workspace.select(document.id) } label: {
                                Text(document.score.title).lineLimit(1).frame(maxWidth: 180)
                            }.help(document.sourceName)
                            Button { workspace.close(document.id) } label: { Image(systemName: "xmark").font(.system(size: 10)) }
                                .accessibilityLabel(L("关闭曲目") + " " + document.score.title)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(workspace.selectedID == document.id ? palette.rule : Color.clear)
                    }
                }
            }
            Button(L(loading ? "正在导入…" : "导入 Guitar Pro")) { importing = true }.disabled(loading)
        }
        .font(.editorial(size: 12 * scale)).buttonStyle(.plain)
        .padding(.horizontal, 24).padding(.top, 12)
    }
    private var demoBody: some View {
        VStack(spacing: 16) {
            HStack {
                Text(L("全指板")).font(.editorial(size: 20 * scale))
                Spacer()
                if !live {
                    Button(L(loading ? "正在导入…" : "导入 Guitar Pro")) { importing = true }.disabled(loading)
                }
                Button(L("完整琴颈")) { follow = false; camera = .overview }
                Button(L("自动取景")) { follow = true; updateCamera() }
                    .buttonStyle(EditorialButtonStyle(prominent: follow))
                if !embedded { Button(L("完成")) { dismiss() }.keyboardShortcut(.cancelAction) }
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
            .frame(minWidth: embedded ? 600 : 900, idealWidth: 960, minHeight: embedded ? 440 : 560, idealHeight: 620)
            .onChange(of: framingNotes) { _ in if live { updateCamera() } }
            .onChange(of: notes) { _ in if live && framingNotes == nil { updateCamera() } }
            .onAppear { if live { updateCamera() } }
            .task(id: playing) {
                guard playing else { return }
                guard notes.indices.contains(step) else { playing = false; return }
                // Set the initial shot immediately; start the clock without a pre-roll.
                updateCamera()
                let clock = ContinuousClock()
                let origin = clock.now
                for event in FretboardPlaybackTimeline.events(startIndex: step, noteCount: notes.count) {
                    do {
                        try await clock.sleep(until: origin.advanced(by: .seconds(event.time)), tolerance: .milliseconds(5))
                    } catch { return }
                    guard !Task.isCancelled else { return }
                    switch event.action {
                    case .frame(let next):
                        let noteDeadline = origin.advanced(by: .seconds(event.time + FretboardPlaybackTimeline.cameraLead))
                        let remaining = clock.now.duration(to: noteDeadline)
                        prepareFrame(at: next, animated: remaining >= .seconds(FretboardPlaybackTimeline.cameraAnimation + 0.08))
                    case .note(let next):
                        step = next
                    case .finish:
                        playing = false
                    }
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
        }
    }
    private func prepareFrame(at next: Int, animated: Bool) {
        guard follow else { return }
        var target = FretboardCamera.preparing(notes, index: next, from: camera)
        // Keep the sounding note on screen while moving toward the next phrase.
        if notes.indices.contains(step) {
            let x = GuitarGeometry.noteX(notes[step].fret)
            if x < target.center - target.width / 2 + 40 || x > target.center + target.width / 2 - 40 {
                target = .fitting([notes[step]] + Array(notes[next..<min(notes.count, next + 3)]))
            }
        }
        guard target != camera else { return }
        var transaction = Transaction()
        // If a UI stall leaves too little lead time, settle immediately instead
        // of delaying a note or letting the pan run across its scheduled onset.
        transaction.disablesAnimations = !animated || reduceMotion
        withTransaction(transaction) { camera = target }
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
    let workspace: GuitarProWorkspace
    var body: some View {
        let shown = Array(practice.notes.prefix(practice.index)) + (practice.hint ? practice.target.map { [$0] } ?? [] : [])
        FullFretboardView(notes: practice.active ? shown : GuitarGeometry.demo,
                          current: max(0, shown.count - 1), live: practice.active,
                          framingNotes: practice.active ? practice.notes : nil,
                          prompt: practice.active ? practice.target.map { $0.fullName + " · \(practice.answered) / 20" } : nil, workspace: workspace)
    }
}
struct ShapeFretboardSheet: View {
    @ObservedObject var drill: ShapePracticeStore
    let workspace: GuitarProWorkspace
    var body: some View {
        let all = drill.question?.shape.tones.map(\.note) ?? []
        let shown = drill.revealed || drill.completed ? all : Array(all.prefix(drill.noteIndex))
        FullFretboardView(notes: drill.active ? shown : GuitarGeometry.demo,
                          current: min(max(0, shown.count - 1), drill.noteIndex), live: drill.active,
                          framingNotes: drill.active ? all : nil,
                          prompt: drill.active ? all.map(\.name).joined(separator: " · ") : nil, workspace: workspace)
    }
}
