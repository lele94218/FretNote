import XCTest
import SwiftUI
import AVFoundation
@testable import FretNoteApp

/// Optional reproducible documentation export. Uses original scores, never user records.
final class ReleaseDemoTests: XCTestCase {
    @MainActor
    func testExportReleaseDemo() throws {
        guard let path = ProcessInfo.processInfo.environment["FRETNOTE_DEMO_EXPORT"],
              let source = ProcessInfo.processInfo.environment["FRETNOTE_DEMO_SCORE"] else { return }
        let directory = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let score = try GuitarProScore.load(URL(fileURLWithPath: source))
        let track = try XCTUnwrap(score.tracks.first)
        let plan = MIDIPlaybackPlan(track: track, firstBar: 1, lastBar: score.barCount, speed: 1)
        let pcm = try ScoreMIDIRenderer.render(plan)
        let audio = try AVAudioFile(forWriting: directory.appendingPathComponent("audio.wav"), settings: pcm.format.settings)
        try audio.write(from: pcm)
        let estimates = ScoreScaleAnalyzer.analyze(score: score, trackID: track.id)
        let camera = FretboardCamera.fitting(track.frames.flatMap(\.positions))
        for frameIndex in 0..<Int(plan.duration * 30) {
            let time = Double(frameIndex) / 30
            let step = track.frames.lastIndex(where: { $0.start <= time }) ?? 0
            let frame = track.frames[step]
            let bends = ScoreBendDisplay.current(track: track, frame: frame, time: time)
            let estimate = estimates[frame.bar] ?? ScoreScaleEstimate(tonic: 4, kind: .minor)
            let view = VStack(spacing: 16) {
                HStack {
                    Text("FretNote").font(.editorial(size: 28, weight: .semibold))
                    Spacer()
                    Text("Guitar Pro · Fretboard player").font(.editorial(size: 16))
                }
                HStack {
                    Text(estimate.tonicName + " · Scale degrees")
                    Spacer()
                    Text(bends.contains(where: \.vibrato) ? (bends.contains(where: \.isBend) ? "Bend + vibrato" : "Vibrato") : "Note playback")
                }.font(.editorial(size: 16)).foregroundStyle(.secondary)
                GuitarInstrumentCanvas(camera: camera, notes: [], current: 0, dark: false,
                    activePositions: frame.positions,
                    upcomingPositions: track.frames.dropFirst(step + 1).first(where: { !$0.notes.isEmpty })?.positions ?? [],
                    barPositions: ScoreBarPositions.positions(in: track.frames, at: step), bends: bends, scaleEstimate: estimate)
                HStack(spacing: 8) {
                    Text("Lead").frame(width: 72, alignment: .leading)
                    ForEach(ScoreBarSegment.make(frames: track.frames)) { segment in
                        Text("\(segment.bar)").frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(time >= segment.start && time < segment.end ? Color.cyan.opacity(0.7) : Color.gray.opacity(0.12))
                    }
                }.font(.editorial(size: 14))
                HStack {
                    Image(systemName: "play.fill")
                    Text("Original demo score · MIDI audio")
                    Spacer()
                    Text(String(format: "%.1f / %.0f s", time, plan.duration)).monospacedDigit()
                }.font(.editorial(size: 13))
            }.padding(28).frame(width: 1000, height: 560).background(.white).foregroundStyle(.black)
                .environment(\.appLanguage, .english).environment(\.interfaceScale, 1).preferredColorScheme(.light)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 1
            let bitmap = NSBitmapImageRep(cgImage: try XCTUnwrap(renderer.cgImage))
            let data = try XCTUnwrap(bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.88]))
            try data.write(to: directory.appendingPathComponent(String(format: "%04d.jpg", frameIndex)))
        }
    }
}
