import Foundation
import Accelerate

public struct ChordReading: Equatable {
    public let midis: [Int]
    public let confidence: Double
    public init(midis: [Int], confidence: Double) { self.midis = midis.sorted(); self.confidence = confidence }
}

/// Conservative clean-tone polyphonic analysis. Estimates pitches independently of the question.
/// Ascending spectral peaks are grouped into harmonic families, preserving sounding octaves.
/// Weak/missing fundamentals, distortion and octave-doubled strings remain limitations.
public final class ChordDetector {
    public static let window = 4096
    private let setup: vDSP_DFT_Setup?
    private let hann: [Float]
    public init() {
        setup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(Self.window), .FORWARD)
        hann = (0..<Self.window).map { Float(0.5 - 0.5 * cos(2 * .pi * Double($0) / Double(Self.window - 1))) }
    }
    deinit { if let setup { vDSP_DFT_DestroySetup(setup) } }
    public func detect(_ samples: [Float], sampleRate: Double, gate: Double = 0.003) -> ChordReading? {
        let n = Self.window
        guard samples.count == n, sampleRate >= 8000, let setup,
              samples.allSatisfy({ $0.isFinite && abs($0) < 0.995 }) else { return nil }
        let rms = sqrt(samples.reduce(0.0) { $0 + Double($1 * $1) } / Double(n))
        guard rms > gate else { return nil }
        let input = zip(samples, hann).map(*)
        let zero = [Float](repeating: 0, count: n)
        var real = zero, imaginary = zero
        vDSP_DFT_Execute(setup, input, zero, &real, &imaginary)
        let magnitude = (0..<n / 2).map { hypot(Double(real[$0]), Double(imaginary[$0])) }
        let binHz = sampleRate / Double(n)
        let lo = max(2, Int(65 / binHz)), hi = min(n / 2 - 2, Int(5000 / binHz))
        guard hi > lo else { return nil }
        let floor = magnitude[lo...hi].sorted()[((hi - lo) / 2)]
        let peak = magnitude[lo...hi].max() ?? 0
        let threshold = max(peak * 0.045, floor * 12)
        guard peak > floor * 20 else { return nil }
        var peaks: [(frequency: Double, amplitude: Double)] = []
        for i in lo...hi where magnitude[i] > threshold && magnitude[i] > magnitude[i - 1] && magnitude[i] >= magnitude[i + 1] {
            let a = log(max(1e-12, magnitude[i - 1])), b = log(max(1e-12, magnitude[i])), c = log(max(1e-12, magnitude[i + 1]))
            let denominator = a - 2 * b + c
            let offset = abs(denominator) > 1e-12 ? max(-0.5, min(0.5, 0.5 * (a - c) / denominator)) : 0
            peaks.append(((Double(i) + offset) * binHz, magnitude[i]))
        }
        func harmonic(_ frequency: Double, of fundamental: Double) -> Bool {
            let multiple = (frequency / fundamental).rounded()
            return (1...16).contains(multiple) && abs(frequency - fundamental * multiple) < max(binHz * 0.7, frequency * 0.009)
        }
        var fundamentals: [(frequency: Double, midi: Int)] = []
        for partial in peaks {
            if fundamentals.contains(where: { harmonic(partial.frequency, of: $0.frequency) }) { continue }
            let value = 69 + 12 * log2(partial.frequency / 440)
            let midi = Int(value.rounded())
            guard (40...85).contains(midi), abs(value - Double(midi)) <= 0.35 else { continue }
            fundamentals.append((partial.frequency, midi))
        }
        guard !fundamentals.isEmpty, fundamentals.count <= 6 else { return nil }
        let total = peaks.reduce(0.0) { $0 + $1.amplitude * $1.amplitude }
        let covered = peaks.filter { peak in fundamentals.contains { harmonic(peak.frequency, of: $0.frequency) } }
            .reduce(0.0) { $0 + $1.amplitude * $1.amplitude }
        let confidence = covered / max(total, 1e-12)
        guard confidence >= 0.9 else { return nil }
        return ChordReading(midis: Array(Set(fundamentals.map(\.midi))), confidence: confidence)
    }
}

/// Stability must exceed the entire analysis window: separated notes in one FFT cannot pass.
/// Release all strings before another chord can emit, including after a wrong chord.
public struct ChordGate {
    private var candidate: [Int] = []
    private var since = 0.0
    private var armed = true
    private var quietSince: Double?
    public init() {}
    public mutating func process(_ reading: ChordReading?, rms: Double, now: Double, gate: Double) -> [Int]? {
        if rms < gate {
            if quietSince == nil { quietSince = now }
            if now - (quietSince ?? now) >= 0.15 { armed = true }
            candidate = []
            return nil
        }
        quietSince = nil
        guard armed, let reading, reading.confidence >= 0.9, reading.midis.count >= 3 else { candidate = []; return nil }
        if candidate != reading.midis { candidate = reading.midis; since = now; return nil }
        guard now - since >= 0.45 else { return nil }
        armed = false
        return candidate
    }
}
