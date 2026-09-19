import Foundation

public struct PitchReading {
    public let frequency: Double
    public let confidence: Double
    public let rms: Double
    public var midi: Int { Int((69 + 12 * log2(frequency / 440)).rounded()) }
    public var cents: Double { 100 * (69 + 12 * log2(frequency / 440) - Double(midi)) }
    public init(frequency: Double, confidence: Double, rms: Double) {
        self.frequency = frequency; self.confidence = confidence; self.rms = rms
    }
}

/// YIN cumulative mean normalized difference, with sub-sample interpolation.
/// Input windows should contain at least 4 periods of the lowest supported note.
public enum PitchDetector {
    public static func detect(_ samples: [Float], sampleRate: Double, gate: Double = 0.003) -> PitchReading? {
        guard samples.count >= 512, sampleRate > 0 else { return nil }
        let rms = sqrt(samples.reduce(0.0) { $0 + Double($1 * $1) } / Double(samples.count))
        guard rms > gate else { return nil }
        let minLag = max(2, Int(sampleRate / 1400))
        let maxLag = min(samples.count / 2, Int(sampleRate / 65))
        guard maxLag > minLag else { return nil }
        let length = samples.count - maxLag
        var difference = [Double](repeating: 0, count: maxLag + 1)
        for lag in 1...maxLag {
            var sum = 0.0
            for i in 0..<length {
                let delta = Double(samples[i] - samples[i + lag])
                sum += delta * delta
            }
            difference[lag] = sum
        }
        var cumulative = 0.0
        difference[0] = 1
        for lag in 1...maxLag {
            cumulative += difference[lag]
            difference[lag] = cumulative > 0 ? difference[lag] * Double(lag) / cumulative : 1
        }
        var lag = minLag
        while lag < maxLag {
            if difference[lag] < 0.15 {
                while lag + 1 <= maxLag && difference[lag + 1] < difference[lag] { lag += 1 }
                break
            }
            lag += 1
        }
        guard lag < maxLag, difference[lag] < 0.2 else { return nil }
        let a = difference[lag - 1], b = difference[lag], c = difference[lag + 1]
        let divisor = a - 2 * b + c
        let adjustment = abs(divisor) > 1e-10 ? 0.5 * (a - c) / divisor : 0
        let frequency = sampleRate / (Double(lag) + adjustment)
        guard frequency.isFinite, (65...1400).contains(frequency) else { return nil }
        return PitchReading(frequency: frequency, confidence: 1 - difference[lag], rms: rms)
    }
}

/// Emits one event for a stable note. Sustained notes do not retrigger.
/// A repeat needs a quiet gap or a new attack; pitch changes can advance legato.
public struct NoteGate {
    private var candidate: Int?
    private var stableFrames = 0
    private var quietFrames = 0
    private var lastEmitted: Int?
    private var lastEvent = -Double.infinity
    private var previousRMS = 0.0
    private var armed = true
    public init() {}
    public mutating func process(_ reading: PitchReading?, rms: Double, now: Double, gate: Double) -> Int? {
        defer { previousRMS = rms }
        if rms < gate {
            quietFrames += 1
            candidate = nil; stableFrames = 0
            if quietFrames >= 3 { armed = true }
            return nil
        }
        quietFrames = 0
        if rms > max(gate * 4, previousRMS * 2.5), now - lastEvent > 0.22 {
            armed = true; stableFrames = 0
        }
        guard let reading, reading.confidence >= 0.85, abs(reading.cents) <= 40 else {
            candidate = nil; stableFrames = 0
            return nil
        }
        if reading.midi == candidate { stableFrames += 1 }
        else { candidate = reading.midi; stableFrames = 1 }
        guard stableFrames >= 3, now - lastEvent > 0.22,
              armed || reading.midi != lastEmitted else { return nil }
        lastEmitted = reading.midi; lastEvent = now; armed = false
        return reading.midi
    }
}
