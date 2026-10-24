import XCTest
import SwiftUI
import AVFoundation
@testable import FretNoteApp

/// Optional reproducible documentation export. Accepts an explicitly supplied score; never reads the user workspace.
final class ReleaseDemoTests: XCTestCase {
    @MainActor
    func testExportReleaseDemo() throws {
        guard let path = ProcessInfo.processInfo.environment["FRETNOTE_DEMO_EXPORT"],
              let source = ProcessInfo.processInfo.environment["FRETNOTE_DEMO_SCORE"] else { return }
        let directory = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let score = try GuitarProScore.load(URL(fileURLWithPath: source))
        let track = try XCTUnwrap(score.tracks.first)
        let first = Int(ProcessInfo.processInfo.environment["FRETNOTE_DEMO_FIRST"] ?? "1") ?? 1
        let last = Int(ProcessInfo.processInfo.environment["FRETNOTE_DEMO_LAST"] ?? "") ?? score.barCount
        let frames = track.selection(from: first, through: last)
        let originals = track.frames.filter { $0.bar >= first && $0.bar <= last }
        XCTAssertFalse(frames.isEmpty)
        let plan = MIDIPlaybackPlan(track: track, firstBar: first, lastBar: last, speed: 1)
        let pcm = try ScoreMIDIRenderer.render(plan)
        let audio = try AVAudioFile(forWriting: directory.appendingPathComponent("audio.wav"), settings: pcm.format.settings)
        try audio.write(from: pcm)
        let estimates = ScoreScaleAnalyzer.analyze(score: score, trackID: track.id)
        let segments = ScoreBarSegment.make(frames: frames)
        let cameras = segments.map { FretboardCamera.fitting(ScoreBarPositions.positions(in: frames, at: $0.id)) }
        func camera(at time: Double) -> FretboardCamera {
            var current = cameras[0]
            for index in 1..<segments.count {
                let start = segments[index].start - FretboardPlaybackTimeline.cameraLead
                if time < start { break }
                let t = min(1, max(0, (time - start) / FretboardPlaybackTimeline.cameraAnimation))
                let eased = t * t * (3 - 2 * t)
                let target = cameras[index]
                current = .init(center: current.center + (target.center-current.center)*eased,
                                width: current.width + (target.width-current.width)*eased)
            }
            return current
        }
        for frameIndex in 0..<Int(plan.duration * 30) {
            let time = Double(frameIndex) / 30
            let step = frames.lastIndex(where: { $0.start <= time }) ?? 0
            let frame = frames[step]
            let bends = ScoreBendDisplay.current(track: track, frame: originals[step], time: originals[step].start + time - frame.start)
            let estimate = estimates[frame.bar]
            let view = VStack(spacing: 16) {
                HStack {
                    Text("FretNote").font(.editorial(size: 34, weight: .semibold))
                    Spacer()
                    Text("Guitar Pro · Fretboard player").font(.editorial(size: 22))
                }
                HStack {
                    Text(estimate.map { $0.tonicName + " " + AppLanguage.english.translate($0.kind.rawValue) + " · Estimated" } ?? "Scale undetermined")
                    Spacer()
                    Text(bends.contains(where: \.vibrato) ? (bends.contains(where: \.isBend) ? "Bend + vibrato" : "Vibrato") : "Note playback")
                }.font(.editorial(size: 22)).foregroundStyle(.secondary)
                GuitarInstrumentCanvas(camera: camera(at: time), notes: [], current: 0, dark: false,
                    activePositions: frame.positions,
                    upcomingPositions: frames.dropFirst(step + 1).first(where: { !$0.notes.isEmpty })?.positions ?? [],
                    barPositions: ScoreBarPositions.positions(in: frames, at: step), bends: bends, scaleEstimate: estimate)
                HStack(spacing: 8) {
                    Text("Lead").frame(width: 72, alignment: .leading)
                    ForEach(segments) { segment in
                        Text("\(segment.bar)").frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(time >= segment.start && time < segment.end ? Color.cyan.opacity(0.7) : Color.gray.opacity(0.12))
                    }
                }.font(.editorial(size: 20))
                HStack {
                    Image(systemName: "play.fill")
                    Text(score.title + " · Bars \(first)–\(last)")
                    Spacer()
                    Text(String(format: "%.1f / %.0f s", time, plan.duration)).monospacedDigit()
                }.font(.editorial(size: 18))
            }.padding(28).frame(width: 1440, height: 810).background(.white).foregroundStyle(.black)
                .environment(\.appLanguage, .english).environment(\.interfaceScale, 1).preferredColorScheme(.light)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 1
            let bitmap = NSBitmapImageRep(cgImage: try XCTUnwrap(renderer.cgImage))
            let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            try data.write(to: directory.appendingPathComponent(String(format: "%04d.png", frameIndex)))
        }
    }
}
