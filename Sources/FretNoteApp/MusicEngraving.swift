import SwiftUI
import CoreText

/// SMuFL uses four staff spaces per em. Outlines avoid text-layout baseline offsets.
enum MusicEngraving {
    private static let resources: Bundle = {
        if let url = Bundle.main.url(forResource: "FretNote_FretNoteApp", withExtension: "bundle"),
           let bundle = Bundle(url: url) { return bundle }
        return Bundle.module
    }()
    static let space: CGFloat = 14
    static let font: CTFont = {
        let url = resources.url(forResource: "Bravura", withExtension: "otf")!
        let provider = CGDataProvider(url: url as CFURL)!
        return CTFontCreateWithGraphicsFont(CGFont(provider)!, space * 4, nil, nil)
    }()
    static let metadata: [String: Any] = {
        let url = resources.url(forResource: "bravura_metadata", withExtension: "json")!
        return try! JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
    }()
    static func engraving(_ key: String) -> CGFloat {
        CGFloat((metadata["engravingDefaults"] as! [String: Any])[key] as! Double) * space
    }
    static func anchor(_ key: String) -> CGPoint {
        let glyphs = metadata["glyphsWithAnchors"] as! [String: [String: [Double]]]
        let value = glyphs["noteheadBlack"]![key]!
        return CGPoint(x: value[0] * space, y: -value[1] * space)
    }
    static func outline(_ character: UniChar) -> Path {
        var character = character
        var glyph: CGGlyph = 0
        precondition(CTFontGetGlyphsForCharacters(font, &character, &glyph, 1) && glyph != 0)
        let path = CTFontCreatePathForGlyph(font, glyph, nil)!
        return Path(path).applying(CGAffineTransform(scaleX: 1, y: -1))
    }
    static let head = outline(0xE0A4)
    static let clef = outline(0xE052) // G clef with octave below, drawn as one glyph.
    static let sharp = outline(0xE262)
    static let natural = outline(0xE261)
    static let headWidth = head.boundingRect.width
    static let stemWidth = engraving("stemThickness")
    static let stemLength = 3.5 * space
    static func stem(down: Bool) -> Path {
        let point = anchor(down ? "stemDownNW" : "stemUpSE")
        // Overlap the outline slightly and paint the head over the stem, so no seam opens when scaled.
        let stem = down
            ? CGRect(x: point.x, y: point.y - 0.5, width: stemWidth, height: stemLength - point.y + 0.5)
            : CGRect(x: point.x - stemWidth, y: -stemLength, width: stemWidth, height: stemLength + point.y + 0.5)
        return Path(stem)
    }
    static let upStem = stem(down: false)
    static let downStem = stem(down: true)
}
