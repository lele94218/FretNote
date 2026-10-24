import AVFoundation
import CTinySoundFont

struct MIDIPlaybackPlan: Sendable {
    var events: [GuitarProScore.MIDIEvent]
    var duration: Double
    var clicks: [GuitarProScore.Beat] = []

    init(track: GuitarProScore.Track, firstBar: Int, lastBar: Int, speed: Double, beats: [GuitarProScore.Beat] = [], timingTrack: GuitarProScore.Track? = nil) {
        guard speed > 0, speed.isFinite else { events = []; duration = 0; return }
        let frames = (timingTrack ?? track).frames.filter { $0.bar >= firstBar && $0.bar <= lastBar }
        var spans: [(start: Double, end: Double)] = []
        for frame in frames {
            if let last = spans.last, abs(last.end - frame.start) < 0.000001 {
                spans[spans.count - 1].end = frame.end
            } else { spans.append((frame.start, frame.end)) }
        }
        events = []; duration = 0
        // A selected bar range can have disjoint occurrences after repeats.
        // Chase controller state and held notes at each cut, without replaying attacks.
        for span in spans {
            events.append(.init(time: duration, kind: 0, channel: 0, key: 0, value: 0))
            var held: [Int: GuitarProScore.MIDIEvent] = [:]
            for event in track.events where event.time < span.start {
                let id = event.channel * 128 + event.key
                switch event.kind {
                case 1: if event.value > 0 { held[id] = event } else { held[id] = nil }
                case 2: held[id] = nil
                default: events.append(event.at(duration))
                }
            }
            events += held.sorted { $0.key < $1.key }.map { $0.value.at(duration) }
            for event in track.events where event.time >= span.start && event.time < span.end {
                events.append(event.at(duration + (event.time - span.start) / speed))
            }
            clicks += beats.filter { $0.time >= span.start && $0.time < span.end }.map {
                .init(time: duration + ($0.time - span.start) / speed, accent: $0.accent)
            }
            duration += (span.end - span.start) / speed
        }
    }
}

/// Renders on a worker before playback. Audio callbacks only consume PCM, so
/// neither the UI nor camera work can interrupt MIDI event scheduling.
enum ScoreMIDIRenderer {
    static let sampleRate = 44_100.0
    static func metronome(_ plan: MIDIPlaybackPlan) throws -> AVAudioPCMBuffer {
        guard plan.duration > 0, plan.duration <= 1200,
              let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount((plan.duration * sampleRate).rounded())) else {
            throw GuitarProScore.ImportError.invalid("无法准备节拍器")
        }
        buffer.frameLength = buffer.frameCapacity
        let output = buffer.floatChannelData![0]
        output.initialize(repeating: 0, count: Int(buffer.frameLength))
        for beat in plan.clicks {
            try Task.checkCancellation()
            let start = Int((beat.time * sampleRate).rounded())
            let length = min(Int(sampleRate * 0.035), Int(buffer.frameLength) - start)
            guard start >= 0, length > 0 else { continue }
            for i in 0..<length {
                let t = Double(i) / sampleRate
                let attack = min(1, t / 0.001)
                output[start + i] += Float(sin(2 * .pi * (beat.accent ? 1800 : 1200) * t) * exp(-t * 140) * attack * (beat.accent ? 0.55 : 0.35))
            }
        }
        return buffer
    }
    static func render(_ plan: MIDIPlaybackPlan) throws -> AVAudioPCMBuffer {
        guard plan.duration > 0, plan.duration <= 1200,
              let font = Bundle.module.url(forResource: "sonivox", withExtension: "sf2"),
              let synth = fn_synth_create(font.path, Int32(sampleRate)),
              let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            throw GuitarProScore.ImportError.invalid("无法准备 MIDI 音频，请将播放范围限制在 20 分钟以内")
        }
        defer { fn_synth_destroy(synth) }
        let count = AVAudioFrameCount((plan.duration * sampleRate).rounded())
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count),
              let output = buffer.floatChannelData?[0] else {
            throw GuitarProScore.ImportError.invalid("无法分配音频缓冲区")
        }
        buffer.frameLength = count
        var cursor = 0
        func renderUntil(_ target: Int) throws {
            while cursor < target {
                try Task.checkCancellation()
                let size = min(4096, target - cursor)
                fn_synth_render(synth, output.advanced(by: cursor), Int32(size))
                cursor += size
            }
        }
        for event in plan.events {
            let position = min(Int(count), max(cursor, Int((event.time * sampleRate).rounded())))
            try renderUntil(position)
            fn_synth_event(synth, Int32(event.kind), Int32(event.channel), Int32(event.key), Int32(event.value))
        }
        try renderUntil(Int(count))
        // Keep loop/cut boundaries click-free without altering duration or pitch.
        let fade = min(128, Int(count) / 2)
        for index in 0..<Int(count) { output[index] = max(-1, min(1, output[index])) }
        for index in 0..<fade {
            let gain = Float(index) / Float(fade)
            output[index] *= gain
            output[Int(count) - 1 - index] *= gain
        }
        return buffer
    }
}

@MainActor
final class ScoreMIDIPlayer: ObservableObject {
    private let engine = AVAudioEngine()
    private let node = AVAudioPlayerNode()
    private let clickNode = AVAudioPlayerNode()
    private var clickBuffer: AVAudioPCMBuffer?
    private var stemNodes: [Int: AVAudioPlayerNode] = [:]
    private var stemBuffers: [Int: AVAudioPCMBuffer] = [:]
    private var leadID = 0
    var mutedTracks: Set<Int> = [] { didSet { updateVolumes() } }
    private func updateVolumes() {
        // Fixed headroom; muting a track never changes the others' gain.
        let gain = volume / Float(sqrt(Double(max(1, stemNodes.count + 1))))
        node.volume = mutedTracks.contains(leadID) ? 0 : gain
        for (id, stem) in stemNodes { stem.volume = mutedTracks.contains(id) ? 0 : gain }
        clickNode.volume = metronomeEnabled ? volume : 0
    }
    var preparedTrackIDs: Set<Int> { Set(stemNodes.keys).union([leadID]) }
    func trackGain(_ id: Int) -> Float { id == leadID ? node.volume : (stemNodes[id]?.volume ?? 0) }
    var metronomeEnabled = false { didSet { clickNode.volume = metronomeEnabled ? volume : 0 } }
    private var cacheKey = ""
    private var buffer: AVAudioPCMBuffer?
    private var startOffset = 0.0
    private var duration = 0.0
    private var loops = false
    private var active = false
    private var generation = 0
    @Published var preparing = false
    var volume: Float = 0.65 { didSet { updateVolumes() } }

    init() {
        engine.attach(node)
        engine.attach(clickNode)
        let format = AVAudioFormat(standardFormatWithSampleRate: ScoreMIDIRenderer.sampleRate, channels: 1)!
        engine.connect(node, to: engine.mainMixerNode, format: format)
        node.volume = volume
        engine.connect(clickNode, to: engine.mainMixerNode, format: format)
        clickNode.volume = 0
    }
    func prepare(track: GuitarProScore.Track, first: Int, last: Int, speed: Double, beats: [GuitarProScore.Beat] = [], accompaniment: [GuitarProScore.Track] = []) async throws {
        let key = "\(track.id):\(first):\(last):\(speed):\(accompaniment.map(\.id))"
        if cacheKey == key, buffer != nil { return }
        generation += 1
        let token = generation
        preparing = true
        defer { if token == generation { preparing = false } }
        let task = Task.detached(priority: .userInitiated) {
            let plan = MIDIPlaybackPlan(track: track, firstBar: first, lastBar: last, speed: speed, beats: beats)
            var stems: [Int: AVAudioPCMBuffer] = [:]
            for other in accompaniment where other.id != track.id {
                try Task.checkCancellation()
                stems[other.id] = try ScoreMIDIRenderer.render(MIDIPlaybackPlan(track: other, firstBar: first, lastBar: last, speed: speed, timingTrack: track))
            }
            return (try ScoreMIDIRenderer.render(plan), try ScoreMIDIRenderer.metronome(plan), stems)
        }
        let rendered = try await withTaskCancellationHandler(operation: { try await task.value }, onCancel: { task.cancel() })
        try Task.checkCancellation()
        guard token == generation else { throw CancellationError() }
        stop()
        for stem in stemNodes.values { engine.detach(stem) }
        stemNodes = [:]
        stemBuffers = rendered.2
        for id in stemBuffers.keys {
            let stem = AVAudioPlayerNode()
            engine.attach(stem)
            engine.connect(stem, to: engine.mainMixerNode, format: rendered.0.format)
            stemNodes[id] = stem
        }
        leadID = track.id
        buffer = rendered.0; clickBuffer = rendered.1; cacheKey = key
        updateVolumes()
    }
    func play(from seconds: Double, looping: Bool) throws {
        guard let buffer else { return }
        node.stop(); clickNode.stop(); stemNodes.values.forEach { $0.stop() }
        duration = Double(buffer.frameLength) / buffer.format.sampleRate
        startOffset = min(max(0, seconds), max(0, duration - 1 / buffer.format.sampleRate))
        loops = looping
        let offset = AVAudioFrameCount((startOffset * buffer.format.sampleRate).rounded())
        func schedule(_ buffer: AVAudioPCMBuffer, on node: AVAudioPlayerNode) throws {
            if offset == 0 {
                node.scheduleBuffer(buffer, at: nil, options: looping ? [.loops] : [], completionHandler: nil)
            } else {
                let length = buffer.frameLength - offset
                guard let remainder = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: length) else {
                    throw GuitarProScore.ImportError.invalid("无法分配音频缓冲区")
                }
                remainder.frameLength = length
                remainder.floatChannelData![0].update(from: buffer.floatChannelData![0].advanced(by: Int(offset)), count: Int(length))
                node.scheduleBuffer(remainder)
                if looping { node.scheduleBuffer(buffer, at: nil, options: [.loops], completionHandler: nil) }
            }
        }
        try schedule(buffer, on: node)
        if let clickBuffer { try schedule(clickBuffer, on: clickNode) }
        for (id, stem) in stemNodes { if let pcm = stemBuffers[id] { try schedule(pcm, on: stem) } }
        try engine.start()
        let start = AVAudioTime(hostTime: mach_absolute_time() + AVAudioTime.hostTime(forSeconds: 0.02))
        node.play(at: start); clickNode.play(at: start)
        stemNodes.values.forEach { $0.play(at: start) }; active = true
    }
    /// Musical position comes from rendered audio samples, not a wall-clock timer.
    var position: Double {
        guard active, let render = node.lastRenderTime, let time = node.playerTime(forNodeTime: render) else { return startOffset }
        let position = startOffset + max(0, Double(time.sampleTime) / time.sampleRate - node.outputPresentationLatency)
        return loops && duration > 0 ? position.truncatingRemainder(dividingBy: duration) : min(duration, position)
    }
    var finished: Bool { active && !loops && position >= duration }
    func setLooping(_ enabled: Bool) throws {
        guard active, enabled != loops else { return }
        let current = position
        try play(from: current, looping: enabled)
    }
    func stop() { active = false; node.stop(); clickNode.stop(); stemNodes.values.forEach { $0.stop() }; engine.stop() }
}
