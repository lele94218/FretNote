import XCTest
import SwiftUI
import FretNoteCore
@testable import FretNoteApp

final class FretboardCameraTests: XCTestCase {
    func testPhysicalFretsAndCameraContainLookAhead() {
        XCTAssertEqual(GuitarGeometry.fretX(12), GuitarGeometry.scaleLength / 2, accuracy: 0.001)
        XCTAssertLessThan(GuitarGeometry.noteX(0), GuitarGeometry.fretX(0))
        for fret in 2...21 {
            XCTAssertLessThan(GuitarGeometry.fretX(fret) - GuitarGeometry.fretX(fret - 1), GuitarGeometry.fretX(fret - 1) - GuitarGeometry.fretX(fret - 2))
        }
        let notes = GuitarGeometry.demo
        for index in notes.indices {
            let camera = FretboardCamera.following(notes, index: index)
            for note in notes[index..<min(notes.count, index + 3)] {
                XCTAssertGreaterThan(GuitarGeometry.noteX(note.fret), camera.center - camera.width / 2)
                XCTAssertLessThan(GuitarGeometry.noteX(note.fret), camera.center + camera.width / 2)
            }
            XCTAssertGreaterThanOrEqual(camera.width, 370)
            XCTAssertLessThanOrEqual(camera.width, FretboardCamera.overview.width)
        }
        XCTAssertEqual(FretboardCamera.following([], index: 0), .overview)
        XCTAssertEqual(FretboardCamera.following(notes, index: notes.count), .overview)
        let wide = FretboardCamera.following([GuitarNote(string: 6, fret: 0), GuitarNote(string: 1, fret: 21)], index: 0)
        let close = FretboardCamera.following([GuitarNote(string: 1, fret: 21)], index: 0)
        XCTAssertGreaterThan(wide.width, close.width)
    }

    @MainActor
    func testRenderCamera() async throws {
        guard let path = ProcessInfo.processInfo.environment["FRETNOTE_CAMERA_SNAPSHOTS"] else { return }
        _ = NSApplication.shared
        let folder = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for (name, live, index, dark) in [("overview", false, 0, false), ("low", true, 2, false), ("high", true, 14, true), ("large-english", false, 0, false)] {
            let host = NSHostingView(rootView: FullFretboardView(notes: GuitarGeometry.demo, current: index, live: live)
                .environment(\.appLanguage, name == "large-english" ? .english : .chinese)
                .environment(\.interfaceScale, name == "large-english" ? 1.75 : 1.25)
                .preferredColorScheme(dark ? .dark : .light).frame(width: 960, height: 620))
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 620), styleMask: [.borderless], backing: .buffered, defer: false)
            window.contentView = host; window.orderFront(nil)
            try await Task.sleep(nanoseconds: 900_000_000)
            host.layoutSubtreeIfNeeded()
            XCTAssertLessThanOrEqual(host.fittingSize.height, 620)
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: folder.appendingPathComponent(name + ".png"))
            window.orderOut(nil)
        }
        // Export deterministic camera samples to review the same transform used by
        // the animated Canvas, without touching microphone or user learning data.
        let targets = [FretboardCamera.overview, .following(GuitarGeometry.demo, index: 2), .following(GuitarGeometry.demo, index: 9), .following(GuitarGeometry.demo, index: 14), .overview]
        for frame in 0..<64 {
            let segment = min(3, frame / 16)
            let t = CGFloat(frame % 16) / 15
            let eased = t * t * (3 - 2 * t)
            let a = targets[segment], b = targets[segment + 1]
            let camera = FretboardCamera(center: a.center + (b.center - a.center) * eased, width: a.width + (b.width - a.width) * eased)
            let view = GuitarInstrumentCanvas(camera: camera, notes: GuitarGeometry.demo, current: [2, 9, 14, 14][segment], dark: false)
                .background(Color.white).frame(width: 960, height: 360)
            let renderer = ImageRenderer(content: view)
            let cgImage = try XCTUnwrap(renderer.cgImage)
            let bitmap = NSBitmapImageRep(cgImage: cgImage)
            try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: folder.appendingPathComponent(String(format: "frame-%03d.png", frame)))
        }
    }
}
