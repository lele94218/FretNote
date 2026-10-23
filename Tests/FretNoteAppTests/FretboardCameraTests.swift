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

    func testMarkersStayOnStringsWithoutCoveringNeighbours() {
        for fret in 1...21 {
            let x = GuitarGeometry.noteX(fret)
            for string in 1...6 {
                let nut = GuitarGeometry.stringY(string, x: 0)
                let bridge = GuitarGeometry.stringY(string, x: GuitarGeometry.scaleLength)
                XCTAssertEqual(GuitarGeometry.stringY(string, x: x), nut + (bridge - nut) * x / GuitarGeometry.scaleLength, accuracy: 0.0001)
            }
            let gap = GuitarGeometry.stringY(2, x: x) - GuitarGeometry.stringY(1, x: x)
            for zoom: CGFloat in [0.3, 0.5, 1, 2, 3] {
                // Includes the stroke on both sides of the marker.
                XCTAssertLessThan(GuitarGeometry.markerRadius(x: x, zoom: zoom) * 2.3, gap)
            }
        }
    }

    func testTracedArtworkIsBundledAndOverviewShowsOnlyBodyShoulder() {
        XCTAssertFalse(NeckArtwork.layers.isEmpty)
        XCTAssertFalse(NeckArtwork.bodyLayers.isEmpty)
        let bounds = NeckArtwork.outline.boundingRect
        XCTAssertFalse(bounds.isEmpty)
        let camera = FretboardCamera.overview
        XCTAssertLessThan(camera.center - camera.width / 2, bounds.minX)
        XCTAssertGreaterThan(camera.center + camera.width / 2, bounds.maxX)
        XCTAssertGreaterThan(camera.center + camera.width / 2, bounds.maxX + 100)
        XCTAssertLessThan(camera.center + camera.width / 2, GuitarGeometry.scaleLength)
        XCTAssertLessThan(bounds.maxX, GuitarGeometry.fretX(21) + 30)
    }

    func testCameraStaysSettledUntilLookAheadLeavesSafeFrame() {
        let notes = [GuitarNote(string: 1, fret: 5), GuitarNote(string: 2, fret: 6),
                     GuitarNote(string: 3, fret: 7), GuitarNote(string: 1, fret: 8),
                     GuitarNote(string: 1, fret: 21)]
        let initial = FretboardCamera.following(notes, index: 0)
        XCTAssertEqual(FretboardCamera.preparing(notes, index: 1, from: initial), initial)
        let prepared = FretboardCamera.preparing(notes, index: 2, from: initial)
        XCTAssertNotEqual(prepared, initial)
        for note in notes[2...] {
            XCTAssertGreaterThan(GuitarGeometry.noteX(note.fret), prepared.center - prepared.width / 2)
            XCTAssertLessThan(GuitarGeometry.noteX(note.fret), prepared.center + prepared.width / 2)
        }
        let live = FretboardCamera.fitting(notes)
        for note in notes {
            XCTAssertGreaterThan(GuitarGeometry.noteX(note.fret), live.center - live.width / 2)
            XCTAssertLessThan(GuitarGeometry.noteX(note.fret), live.center + live.width / 2)
        }
    }

    @MainActor
    func testRenderCamera() async throws {
        guard let path = ProcessInfo.processInfo.environment["FRETNOTE_CAMERA_SNAPSHOTS"] else { return }
        _ = NSApplication.shared
        let folder = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for (name, live, index, dark) in [("overview", false, 0, false), ("low", true, 2, false), ("high", true, 14, true), ("large-english", false, 0, false)] {
            let host = NSHostingView(rootView: FullFretboardView(notes: GuitarGeometry.demo, current: index, live: live,
                framingNotes: live ? Array(GuitarGeometry.demo[index..<min(index + 3, GuitarGeometry.demo.count)]) : nil)
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
        let targets = [FretboardCamera.overview, .following(GuitarGeometry.demo, index: 2), .following(GuitarGeometry.demo, index: 9), .following(GuitarGeometry.demo, index: 14)]
        for frame in 0..<72 {
            let segment = frame / 24
            let moving = frame % 24 < 9
            let t = min(1, CGFloat(frame % 24) / 8)
            let eased = t * t * (3 - 2 * t)
            let a = targets[segment], b = targets[segment + 1]
            let camera = FretboardCamera(center: a.center + (b.center - a.center) * eased, width: a.width + (b.width - a.width) * eased)
            let view = GuitarInstrumentCanvas(camera: camera, notes: moving ? [] : GuitarGeometry.demo, current: [2, 9, 14][segment], dark: false)
                .background(Color.white).frame(width: 960, height: 360)
            let renderer = ImageRenderer(content: view)
            let cgImage = try XCTUnwrap(renderer.cgImage)
            let bitmap = NSBitmapImageRep(cgImage: cgImage)
            try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: folder.appendingPathComponent(String(format: "frame-%03d.png", frame)))
        }
    }
}
