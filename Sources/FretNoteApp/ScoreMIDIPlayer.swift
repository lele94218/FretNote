import AVFoundation
import CTinySoundFont

struct MIDIPlaybackPlan: Sendable {
    var events: [GuitarProScore.MIDIEvent]
    var duration: Double

    init(track: GuitarProScore.Track, firstBar: Int, lastBar: Int, speed: Double) {
        guard speed > 0, speed.isFinite else { events = []; duration = 0; return }
        let frames = track.frames.filter { $0.bar >= firstBar && $0.bar <= lastBar }
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
            duration += (span.end - span.start) / speed
        }
    }
}

/// Renders on a worker before playback. Audio callbacks only consume PCM, so
/// neither the UI nor camera work can interrupt MIDI event scheduling.
enum ScoreMIDIRenderer {
    static let sampleRate = 44_100.0
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
    private var cacheKey = ""
    private var buffer: AVAudioPCMBuffer?
    private var startOffset = 0.0
    private var duration = 0.0
    private var loops = false
    private var active = false
    private var generation = 0
    @Published var preparing = false
    var volume: Float = 0.65 { didSet { node.volume = volume } }

    init() {
        engine.attach(node)
        let format = AVAudioFormat(standardFormatWithSampleRate: ScoreMIDIRenderer.sampleRate, channels: 1)!
        engine.connect(node, to: engine.mainMixerNode, format: format)
        node.volume = volume
    }
    func prepare(track: GuitarProScore.Track, first: Int, last: Int, speed: Double) async throws {
        let key = "\(track.id):\(first):\(last):\(speed)"
        if cacheKey == key, buffer != nil { return }
        generation += 1
        let token = generation
        preparing = true
        defer { if token == generation { preparing = false } }
        let task = Task.detached(priority: .userInitiated) {
            try ScoreMIDIRenderer.render(MIDIPlaybackPlan(track: track, firstBar: first, lastBar: last, speed: speed))
        }
        let rendered = try await withTaskCancellationHandler(operation: { try await task.value }, onCancel: { task.cancel() })
        try Task.checkCancellation()
        guard token == generation else { throw CancellationError() }
        buffer = rendered; cacheKey = key
    }
    func play(from seconds: Double, looping: Bool) throws {
        guard let buffer else { return }
        node.stop()
        duration = Double(buffer.frameLength) / buffer.format.sampleRate
        startOffset = min(max(0, seconds), max(0, duration - 1 / buffer.format.sampleRate))
        loops = looping
        let offset = AVAudioFrameCount((startOffset * buffer.format.sampleRate).rounded())
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
        try engine.start()
        node.play(); active = true
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
    func stop() { active = false; node.stop(); engine.stop() }
}
