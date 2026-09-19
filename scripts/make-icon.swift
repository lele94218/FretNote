import AppKit

// Deterministic vector artwork, rendered at each macOS icon size.
// Six strings, three frets, and one position marker. Coordinates are on a 1024 grid.
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
func render(_ pixels: Int, filename: String) throws {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                 isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    let cg = context.cgContext
    cg.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    NSColor(white: 0.08, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 196, yRadius: 196).fill()
    NSColor(white: 0.92, alpha: 1).setStroke()
    for string in 0..<6 {
        let y = 292 + CGFloat(string) * 88
        let line = NSBezierPath()
        line.move(to: NSPoint(x: 240, y: y))
        line.line(to: NSPoint(x: 784, y: y))
        line.lineWidth = 10
        line.lineCapStyle = .round
        line.stroke()
    }
    NSColor(white: 0.55, alpha: 1).setStroke()
    for x in [272.0, 512.0, 752.0] {
        let line = NSBezierPath()
        line.move(to: NSPoint(x: x, y: 268))
        line.line(to: NSPoint(x: x, y: 756))
        line.lineWidth = 10
        line.stroke()
    }
    NSColor(white: 0.08, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: 562, y: 486, width: 140, height: 140)).fill()
    NSColor.white.setFill()
    NSBezierPath(ovalIn: NSRect(x: 580, y: 504, width: 104, height: 104)).fill()
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(filename))
}
for size in [16, 32, 128, 256, 512] {
    try render(size, filename: "icon_\(size)x\(size).png")
    try render(size * 2, filename: "icon_\(size)x\(size)@2x.png")
}
