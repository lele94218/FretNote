import SwiftUI
import FretNoteCore

/// Uses score timestamps, never camera animation completion, as the transport clock.
struct GuitarProPlaybackView: View, Localizable {
    @Environment(\.appLanguage) var language
    @Environment(\.colorScheme) private var scheme
    @Environment(\.interfaceScale) private var scale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    let score: GuitarProScore
    let close: () -> Void
    @State private var trackID: Int
    @State private var firstBar = 1
    @State private var lastBar: Int
    @State private var speed = 1.0
    @State private var looping = false
    @State private var playing = false
    @State private var step = 0
    @State private var follow = true
    @State private var camera = FretboardCamera.overview

    init(score: GuitarProScore, close: @escaping () -> Void) {
        self.score = score; self.close = close
        _trackID = State(initialValue: score.tracks.first(where: \.supported)?.id ?? 0)
        _lastBar = State(initialValue: score.barCount)
    }
    private var palette: AppPalette { AppPalette(scheme: scheme) }
    private var frames: [GuitarProScore.Frame] {
        score.tracks.first { $0.id == trackID }?.selection(from: firstBar, through: lastBar) ?? []
    }
    private var frame: GuitarProScore.Frame? { frames.indices.contains(step) ? frames[step] : nil }
    private var nextPositions: [GuitarNote] { frames.dropFirst(step + 1).first { !$0.notes.isEmpty }?.positions ?? [] }
    private var techniques: String {
        guard let frame else { return "" }
        var labels: [String] = []
        if frame.notes.contains(where: { !$0.bend.isEmpty }) { labels.append(L("推弦")) }
        if frame.notes.contains(where: \.slide) { labels.append(L("滑音")) }
        if frame.notes.contains(where: \.legato) { labels.append(L("击勾弦")) }
        if frame.notes.contains(where: \.tie) { labels.append(L("延音")) }
        return labels.joined(separator: " · ")
    }
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button { playing = false; close() } label: { Image(systemName: "chevron.left") }.accessibilityLabel(L("返回"))
                Text(score.title).font(.editorial(size: 20 * scale)).lineLimit(1)
                Spacer()
                Button(L("完整琴颈")) { follow = false; camera = .overview }
                Button(L("自动取景")) { follow = true; settle() }.buttonStyle(EditorialButtonStyle(prominent: follow))
                Button(L("完成")) { dismiss() }.keyboardShortcut(.cancelAction)
            }
            HStack(spacing: 12) {
                Picker(L("音轨"), selection: $trackID) {
                    ForEach(score.tracks.filter(\.supported)) { Text($0.name).tag($0.id) }
                }.labelsHidden().frame(maxWidth: 220)
                Text(L("小节"))
                TextField("1", value: $firstBar, format: .number).frame(width: 44).accessibilityLabel(L("起始小节"))
                Text("–")
                TextField("1", value: $lastBar, format: .number).frame(width: 44).accessibilityLabel(L("结束小节"))
                Spacer()
                Picker(L("速度"), selection: $speed) {
                    ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { Text("\(Int($0 * 100))%").tag($0) }
                }.frame(width: 145)
                Toggle(L("循环"), isOn: $looping).toggleStyle(.checkbox)
            }.textFieldStyle(.roundedBorder)
            HStack {
                Text(L("指板跟谱 · 无声播放"))
                Spacer()
                Text(frame?.notes.isEmpty == true ? L("休止") : (frame?.positions.map(\.fullName).joined(separator: " + ") ?? ""))
                Text(techniques)
                Text("\(frame?.bar ?? firstBar) / \(score.barCount)").monospacedDigit()
            }.foregroundStyle(palette.muted).lineLimit(1)
            GuitarInstrumentCanvas(camera: camera, notes: [], current: 0, dark: scheme == .dark,
                                  activePositions: frame?.positions ?? [], upcomingPositions: nextPositions)
                .animation(reduceMotion ? nil : .easeInOut(duration: FretboardPlaybackTimeline.cameraAnimation), value: camera)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack(spacing: 16) {
                Button { seek(max(0, step - 1)) } label: { Image(systemName: "backward.end") }.accessibilityLabel(L("上一个音"))
                Button(L(playing ? "暂停" : "播放")) {
                    if step >= frames.count - 1 { step = 0 }
                    playing.toggle()
                }.buttonStyle(EditorialButtonStyle(prominent: true)).disabled(frames.isEmpty).keyboardShortcut(.space, modifiers: [])
                Button { seek(min(max(0, frames.count - 1), step + 1)) } label: { Image(systemName: "forward.end") }.accessibilityLabel(L("下一个音"))
                Slider(value: Binding(get: { Double(step) }, set: { seek(Int($0)) }), in: 0...Double(max(1, frames.count - 1)), step: 1).accessibilityLabel(L("乐谱进度"))
                Text("\(frames.isEmpty ? 0 : step + 1) / \(frames.count)").monospacedDigit()
            }
        }
        .padding(24).font(.editorial(size: 12 * scale))
        .foregroundStyle(palette.ink).background(palette.background)
        .buttonStyle(EditorialButtonStyle())
        .frame(minWidth: 900, idealWidth: 960, minHeight: 560, idealHeight: 620)
        .onAppear { settle() }
        .onChange(of: trackID) { _ in seek(0) }
        .onChange(of: firstBar) { _ in firstBar = max(1, min(score.barCount, firstBar)); lastBar = max(firstBar, lastBar); seek(0) }
        .onChange(of: lastBar) { _ in lastBar = max(firstBar, min(score.barCount, lastBar)); seek(0) }
        .onChange(of: speed) { _ in playing = false }
        .task(id: playing) {
            guard playing, frames.indices.contains(step) else { return }
            let sequence = frames
            let clock = ContinuousClock()
            var origin = clock.now
            var from = step
            repeat {
                settle()
                let events = ScorePlaybackTimeline.events(frames: sequence, startIndex: from, speed: speed)
                for event in events {
                    do { try await clock.sleep(until: origin.advanced(by: .seconds(event.time)), tolerance: .milliseconds(3)) }
                    catch { return }
                    guard !Task.isCancelled else { return }
                    switch event.action {
                    case .frame(let next):
                        let deadline = (sequence[next].start - sequence[from].start) / speed
                        let remaining = clock.now.duration(to: origin.advanced(by: .seconds(deadline)))
                        prepare(next, animated: remaining >= .seconds(FretboardPlaybackTimeline.cameraAnimation + 0.05))
                    case .note(let next): step = next
                    case .finish: break
                    }
                }
                if looping {
                    origin = origin.advanced(by: .seconds(events.last?.time ?? 0))
                    from = 0; step = 0
                } else { playing = false }
            } while looping && !Task.isCancelled
        }
    }
    private func seek(_ index: Int) { playing = false; step = index; settle() }
    private func lookAhead(_ index: Int) -> [GuitarNote] {
        guard frames.indices.contains(index) else { return [] }
        let end = frames[index].start + 1.6 * speed
        return frames.dropFirst(index).prefix { $0.start <= end }.flatMap(\.positions)
    }
    private func settle() {
        guard follow else { return }
        var transaction = Transaction(); transaction.disablesAnimations = true
        withTransaction(transaction) { camera = .fitting(lookAhead(step)) }
    }
    private func prepare(_ next: Int, animated: Bool) {
        guard follow, frames.indices.contains(next) else { return }
        let targetNotes = frames[next].positions
        guard targetNotes.contains(where: {
            let x = GuitarGeometry.noteX($0.fret)
            return x < camera.center - camera.width / 2 + 65 || x > camera.center + camera.width / 2 - 65
        }) else { return }
        // Include every intervening note, so fast phrases remain visible during the pan.
        let positions = frames[min(step, next)...next].flatMap(\.positions) + lookAhead(next)
        var transaction = Transaction(); transaction.disablesAnimations = !animated || reduceMotion
        withTransaction(transaction) { camera = .fitting(positions) }
    }
}

enum ScorePlaybackTimeline {
    static func events(frames: [GuitarProScore.Frame], startIndex: Int, speed: Double) -> [FretboardPlaybackTimeline.Event] {
        guard frames.indices.contains(startIndex), speed > 0, speed.isFinite else { return [] }
        let origin = frames[startIndex].start
        var events: [FretboardPlaybackTimeline.Event] = []
        for index in (startIndex + 1)..<frames.count {
            let onset = (frames[index].start - origin) / speed
            events.append(.init(time: max(0, onset - FretboardPlaybackTimeline.cameraLead), action: .frame(index)))
            events.append(.init(time: onset, action: .note(index)))
        }
        events.sort { $0.time < $1.time }
        events.append(.init(time: (frames.last!.end - origin) / speed, action: .finish))
        return events
    }
}
