import AVFoundation
import CoreAudio
import FretNoteCore

struct InputDevice: Identifiable, Equatable {
    let id: AudioDeviceID
    let name: String
    let channels: Int

    static func all() -> [InputDevice] {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        let status = ids.withUnsafeMutableBytes { AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, $0.baseAddress!) }
        guard status == noErr else { return [] }
        return ids.compactMap { id in
            var config = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreamConfiguration, mScope: kAudioDevicePropertyScopeInput, mElement: kAudioObjectPropertyElementMain)
            var bytes: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(id, &config, 0, nil, &bytes) == noErr, bytes > 0 else { return nil }
            let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(bytes), alignment: MemoryLayout<AudioBufferList>.alignment)
            defer { raw.deallocate() }
            guard AudioObjectGetPropertyData(id, &config, 0, nil, &bytes, raw) == noErr else { return nil }
            let list = UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self))
            let channels = list.reduce(0) { $0 + Int($1.mNumberChannels) }
            guard channels > 0 else { return nil }
            var nameAddress = AudioObjectPropertyAddress(mSelector: kAudioObjectPropertyName, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            var name: Unmanaged<CFString>?
            var nameSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            guard AudioObjectGetPropertyData(id, &nameAddress, 0, nil, &nameSize, &name) == noErr,
                  let name else { return nil }
            return InputDevice(id: id, name: name.takeRetainedValue() as String, channels: channels)
        }
    }
    static func defaultID() -> AudioDeviceID {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var id: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        _ = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &id)
        return id
    }
}

/// All mutable analysis state stays on the serial processing queue.
final class AudioAnalyzer {
    var pending: [Float] = []
    private var decimationRemainder: [Float] = []
    var noteGate = NoteGate()
    var clock = 0.0
    let gate: Double
    init(gate: Double) { self.gate = gate }
    func consume(_ samples: [Float], rate: Double, report: (PitchReading?, Double, Int?) -> Void) {
        // Average before decimation to suppress high-frequency content.
        let factor = max(1, Int(rate / 12_000))
        let source = decimationRemainder + samples
        guard source.count >= factor else { decimationRemainder = source; return }
        let analysisRate = rate / Double(factor)
        var reduced: [Float] = []
        reduced.reserveCapacity(source.count / factor)
        let consumed = source.count / factor * factor
        for offset in stride(from: 0, to: consumed, by: factor) {
            var total: Float = 0
            for i in 0..<factor { total += source[offset + i] }
            reduced.append(total / Float(factor))
        }
        decimationRemainder = Array(source[consumed...])
        pending.append(contentsOf: reduced)
        let window = 1536, hop = 384
        while pending.count >= window {
            let frame = Array(pending.prefix(window))
            let rms = sqrt(frame.reduce(0.0) { $0 + Double($1 * $1) } / Double(window))
            let pitch = PitchDetector.detect(frame, sampleRate: analysisRate, gate: gate)
            clock += Double(hop) / analysisRate
            let event = noteGate.process(pitch, rms: rms, now: clock, gate: gate)
            report(pitch, rms, event)
            pending.removeFirst(hop)
        }
    }
}

@MainActor
final class AudioInput: ObservableObject {
    @Published var learningMode = false { didSet { if learningMode { stop() } } }
    @Published var devices = InputDevice.all()
    @Published var selectedDevice = InputDevice.defaultID()
    @Published var channel = 0
    @Published var gateDB = -45.0
    @Published var running = false
    @Published var starting = false
    @Published var error: String?
    @Published var reading: PitchReading?
    @Published var level = 0.0
    var onNote: ((Int) -> Void)?
    private var engine: AVAudioEngine?
    private let queue = DispatchQueue(label: "FretNote.audio-analysis", qos: .userInitiated)
    private var generation = UUID()
    private var configurationObserver: NSObjectProtocol?

    var channelCount: Int { devices.first { $0.id == selectedDevice }?.channels ?? 1 }
    func refresh() {
        devices = InputDevice.all()
        if !devices.contains(where: { $0.id == selectedDevice }) { selectedDevice = InputDevice.defaultID() }
        channel = min(channel, max(0, channelCount - 1))
    }
    func start() async {
        guard !learningMode, !running, !starting else { return }
        starting = true
        defer { starting = false }
        error = nil
        let requestToken = generation
        let allowed = await AVCaptureDevice.requestAccess(for: .audio)
        guard !learningMode, generation == requestToken else { return }
        guard allowed else {
            error = "请在系统设置 → 隐私与安全性 → 麦克风中允许 FretNote，然后重试。"
            return
        }
        let engine = AVAudioEngine()
        let input = engine.inputNode
        guard let unit = input.audioUnit else { error = "无法创建音频输入。"; return }
        var device = selectedDevice
        let status = AudioUnitSetProperty(unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &device, UInt32(MemoryLayout<AudioDeviceID>.size))
        guard status == noErr else { error = "无法打开所选声卡（\(status)），请刷新设备后重试。"; return }
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > channel else { error = "输入通道不可用，请重新选择。"; return }
        let selectedChannel = channel
        let analyzer = AudioAnalyzer(gate: pow(10, gateDB / 20))
        let token = UUID()
        generation = token
        let analysisQueue = queue
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let data = buffer.floatChannelData, buffer.frameLength > 0 else { return }
            let samples: [Float]
            if buffer.format.isInterleaved {
                let channels = Int(buffer.format.channelCount)
                samples = (0..<Int(buffer.frameLength)).map { data[0][$0 * channels + selectedChannel] }
            } else {
                samples = Array(UnsafeBufferPointer(start: data[selectedChannel], count: Int(buffer.frameLength)))
            }
            let rate = buffer.format.sampleRate
            analysisQueue.async {
                analyzer.consume(samples, rate: rate) { pitch, rms, event in
                    Task { @MainActor [weak self] in
                        guard let self, self.generation == token, self.running else { return }
                        self.reading = pitch
                        self.level = rms
                        if let event { self.onNote?(event) }
                    }
                }
            }
        }
        do {
            engine.prepare()
            try engine.start()
            self.engine = engine
            running = true
            configurationObserver = NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.running else { return }
                    self.stop()
                    self.refresh()
                    self.error = "音频设备配置已变化。请确认设备和通道，再点击开始监听。"
                }
            }
        } catch {
            input.removeTap(onBus: 0)
            self.error = "音频启动失败：\(error.localizedDescription)"
        }
    }
    func stop() {
        generation = UUID()
        if let observer = configurationObserver { NotificationCenter.default.removeObserver(observer) }
        configurationObserver = nil
        engine?.stop()
        engine?.inputNode.removeTap(onBus: 0)
        engine = nil
        running = false; reading = nil; level = 0
    }
}
