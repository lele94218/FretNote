import SwiftUI
import FretNoteCore

/// Uses score timestamps, never camera animation completion, as the transport clock.
struct GuitarProPlaybackView: View, Localizable {
    @Environment(\.appLanguage) var language
    @Environment(\.colorScheme) private var scheme
    @Environment(\.interfaceScale) private var scale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    var embedded = false
    let score: GuitarProScore
    let close: () -> Void
    @StateObject private var audio = ScoreMIDIPlayer()
    @State private var volume = 0.65
    @State private var resumePosition: Double?
    @State private var playbackPosition = 0.0
    @State private var audioError: String?
    @State private var trackID: Int
    @State private var firstBar = 1
    @State private var lastBar: Int
    @State private var speed = 1.0
    @State private var looping = false
    @State private var playing = false
    @State private var step = 0
    @State private var follow = true
    @State private var camera = FretboardCamera.overview

    init(score: GuitarProScore, embedded: Bool = false, close: @escaping () -> Void) {
        self.score = score; self.close = close; self.embedded = embedded
        _trackID = State(initialValue: score.tracks.first(where: \.supported)?.id ?? 0)
        _lastBar = State(initialValue: score.barCount)
    }
    private var palette: AppPalette { AppPalette(scheme: scheme) }
    private var frames: [GuitarProScore.Frame] {
        score.tracks.first { $0.id == trackID }?.selection(from: firstBar, through: lastBar) ?? []
    }
    private var frame: GuitarProScore.Frame? { frames.indices.contains(step) ? frames[step] : nil }
    private var nextPositions: [GuitarNote] { frames.dropFirst(step + 1).first { !$0.notes.isEmpty }?.positions ?? [] }
    private var bends: [ScoreBendDisplay] {
        guard let track = score.tracks.first(where: { $0.id == trackID }), let frame else { return [] }
        let source = track.frames.filter { $0.bar >= firstBar && $0.bar <= lastBar }
        guard source.indices.contains(step) else { return [] }
        let elapsed = min(frame.end - frame.start, max(0, playbackPosition * speed - frame.start))
        return ScoreBendDisplay.current(track: track, frame: source[step], time: source[step].start + elapsed)
    }
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
                if !embedded { Button(L("完成")) { dismiss() }.keyboardShortcut(.cancelAction) }
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
                Text(L(audio.preparing ? "正在准备音频…" : "指板跟谱 · MIDI 播放"))
                Spacer()
                Text(frame?.notes.isEmpty == true ? L("休止") : (frame?.positions.map(\.fullName).joined(separator: " + ") ?? ""))
                Text(techniques)
                Text("\(frame?.bar ?? firstBar) / \(score.barCount)").monospacedDigit()
            }.foregroundStyle(palette.muted).lineLimit(1)
            GuitarInstrumentCanvas(camera: camera, notes: [], current: 0, dark: scheme == .dark,
                                  activePositions: frame?.positions ?? [], upcomingPositions: nextPositions,
                                  barPositions: ScoreBarPositions.positions(in: frames, at: step), bends: bends)
                .animation(reduceMotion ? nil : .easeInOut(duration: FretboardPlaybackTimeline.cameraAnimation), value: camera)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            ScoreBarTimeline(segments: ScoreBarSegment.make(frames: frames), step: step,
                             position: playbackPosition * speed, seek: seek)
            HStack(spacing: 16) {
                Button { seek(max(0, step - 1)) } label: { Image(systemName: "backward.end") }.accessibilityLabel(L("上一个音"))
                Button(L(playing ? "暂停" : "播放")) {
                    if playing {
                        resumePosition = audio.preparing ? nil : audio.position
                        playing = false; audio.stop()
                    } else {
                        if step >= frames.count - 1 && resumePosition == nil { step = 0 }
                        playing = true
                    }
                }.buttonStyle(EditorialButtonStyle(prominent: true)).disabled(frames.isEmpty).keyboardShortcut(.space, modifiers: [])
                Button { seek(min(max(0, frames.count - 1), step + 1)) } label: { Image(systemName: "forward.end") }.accessibilityLabel(L("下一个音"))
                Spacer()
                Image(systemName: volume == 0 ? "speaker.slash" : "speaker.wave.2").accessibilityHidden(true)
                Slider(value: $volume, in: 0...1).frame(width: 90).accessibilityLabel(L("音量"))
                Text("\(frames.isEmpty ? 0 : step + 1) / \(frames.count)").monospacedDigit()
            }
        }
        .padding(24).font(.editorial(size: 12 * scale))
        .foregroundStyle(palette.ink).background(palette.background)
        .buttonStyle(EditorialButtonStyle())
        .frame(minWidth: embedded ? 600 : 900, idealWidth: 960, minHeight: embedded ? 440 : 560, idealHeight: 620)
        .onAppear { settle() }
        .onChange(of: trackID) { _ in seek(0) }
        .onChange(of: firstBar) { _ in firstBar = max(1, min(score.barCount, firstBar)); lastBar = max(firstBar, lastBar); seek(0) }
        .onChange(of: lastBar) { _ in lastBar = max(firstBar, min(score.barCount, lastBar)); seek(0) }
        .onChange(of: speed) { _ in seek(step) }
        .onChange(of: volume) { audio.volume = Float($0) }
        .onChange(of: playing) { if !$0 { audio.stop() } }
        .onChange(of: looping) { value in
            do { try audio.setLooping(value) } catch { audioError = error.localizedDescription; playing = false }
        }
        .onDisappear { audio.stop() }
        .alert(L("无法播放"), isPresented: Binding(get: { audioError != nil }, set: { if !$0 { audioError = nil } })) {
            Button(L("好")) { audioError = nil }
        } message: { Text(L(audioError ?? "")) }
        .task(id: playing) {
            guard playing, frames.indices.contains(step), let track = score.tracks.first(where: { $0.id == trackID }) else { return }
            let sequence = frames
            do {
                try await audio.prepare(track: track, first: firstBar, last: lastBar, speed: speed)
                try Task.checkCancellation()
                audio.volume = Float(volume)
                try audio.play(from: resumePosition ?? sequence[step].start / speed, looping: looping)
                resumePosition = nil
                settle()
                var nextCue = step + 1
                var previousPosition = audio.position
                while !Task.isCancelled {
                    let position = audio.position
                    playbackPosition = position
                    if position + 0.001 < previousPosition {
                        step = 0; nextCue = 1; settle()
                    }
                    previousPosition = position
                    while step + 1 < sequence.count && sequence[step + 1].start / speed <= position { step += 1 }
                    while nextCue < sequence.count && sequence[nextCue].start / speed - FretboardPlaybackTimeline.cameraLead <= position {
                        if nextCue > step {
                            prepare(nextCue, animated: sequence[nextCue].start / speed - position >= FretboardPlaybackTimeline.cameraAnimation + 0.05)
                        }
                        nextCue += 1
                    }
                    if audio.finished { playing = false; resumePosition = nil; break }
                    try await Task.sleep(nanoseconds: 16_000_000)
                }
            } catch is CancellationError { return }
            catch { audioError = error.localizedDescription; playing = false }
        }
    }
    private func seek(_ index: Int) { playing = false; audio.stop(); resumePosition = nil; step = index; playbackPosition = (frame?.start ?? 0) / speed; settle() }
    private func lookAhead(_ index: Int) -> [GuitarNote] {
        guard frames.indices.contains(index) else { return [] }
        let end = frames[index].start + 1.6 * speed
        return ScoreBarPositions.positions(in: frames, at: index) + frames.dropFirst(index).prefix { $0.start <= end }.flatMap(\.positions)
    }
    private func settle() {
        guard follow else { return }
        var transaction = Transaction(); transaction.disablesAnimations = true
        withTransaction(transaction) { camera = .fitting(lookAhead(step)) }
    }
    private func prepare(_ next: Int, animated: Bool) {
        guard follow, frames.indices.contains(next) else { return }
        let targetNotes = ScoreBarPositions.positions(in: frames, at: next)
        guard targetNotes.contains(where: {
            let x = GuitarGeometry.noteX($0.fret)
            return x < camera.center - camera.width / 2 + 65 || x > camera.center + camera.width / 2 - 65
        }) else { return }
        // Include every intervening note, so fast phrases remain visible during the pan.
        let positions = ScoreBarPositions.positions(in: frames, at: step) + frames[min(step, next)...next].flatMap(\.positions) + lookAhead(next)
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
