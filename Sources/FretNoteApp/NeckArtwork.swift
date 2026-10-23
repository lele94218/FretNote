import SwiftUI

/// Photo-traced curves, decoded once. Every zoom renders vector paths, not a bitmap.
enum NeckArtwork {
    struct Layer {
        let path: Path
        let color: Color
    }
    private struct EncodedLayer: Decodable {
        let color: [Double]
        let contours: [[Double]]
    }
    private struct EncodedArtwork: Decodable {
        let outline: [[Double]]
        let layers: [EncodedLayer]
    }
    private static func load(_ name: String) -> EncodedArtwork? {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let encoded = try? JSONDecoder().decode(EncodedArtwork.self, from: data) else { return nil }
        return encoded
    }
    private static let artwork = load("NeckArtwork")
    static let outline = Path { p in
        guard let points = artwork?.outline, let first = points.first else { return }
        p.move(to: CGPoint(x: first[0], y: first[1]))
        for point in points.dropFirst() { p.addLine(to: CGPoint(x: point[0], y: point[1])) }
        p.closeSubpath()
    }
    static let layers = makeLayers(artwork)
    static let bodyLayers = makeLayers(load("BodyArtwork"))
    private static func makeLayers(_ artwork: EncodedArtwork?) -> [Layer] {
        (artwork?.layers ?? []).map { layer in
            let path = Path { p in
                for contour in layer.contours where contour.count >= 8 {
                    p.move(to: CGPoint(x: contour[0], y: contour[1]))
                    for i in stride(from: 2, through: contour.count - 6, by: 6) {
                        p.addCurve(to: CGPoint(x: contour[i + 4], y: contour[i + 5]),
                                   control1: CGPoint(x: contour[i], y: contour[i + 1]),
                                   control2: CGPoint(x: contour[i + 2], y: contour[i + 3]))
                    }
                    p.closeSubpath()
                }
            }
            return Layer(path: path, color: Color(red: layer.color[0] / 255,
                                                   green: layer.color[1] / 255,
                                                   blue: layer.color[2] / 255))
        }
    }
    static func tuningPost(_ string: Int) -> CGPoint {
        // Bore centers measured from the same photo as the traced outline.
        let centers: [(CGFloat, CGFloat)] = [(1010, 88), (990, 158), (968, 228),
                                             (948, 298), (926, 368), (906, 438)]
        let center = centers[string - 1]
        let scale: CGFloat = 600 / 996
        return CGPoint(x: (center.1 - 559) * scale, y: (970 - center.0) * scale)
    }
}
