import SwiftUI
import CoreText

/// Local SSENSE faces retain their original names and glyphs. Public builds use
/// bundled OFL Inter when the user's non-redistributable font files are absent.
enum AppTypography {
    private static let resources: Bundle = {
        if let url = Bundle.main.url(forResource: "FretNote_FretNoteApp", withExtension: "bundle"),
           let bundle = Bundle(url: url) { return bundle }
        return Bundle.module
    }()
    private static let localFonts: [String: CGFont] = {
        var fonts: [String: CGFont] = [:]
        for face in ["Inter", "Regular"] {
            if let url = resources.url(forResource: "FavoritSSENSE-\(face)", withExtension: "ttf"),
               let provider = CGDataProvider(url: url as CFURL), let font = CGFont(provider) {
                fonts[face] = font
            }
        }
        return fonts
    }()
    static var usesLocalSSENSE: Bool { localFonts["Inter"] != nil && localFonts["Regular"] != nil }
    private static let registered: Void = {
        for face in ["Regular", "Medium", "Bold"] {
            guard let url = resources.url(forResource: "Inter-\(face)", withExtension: "ttf") else {
                preconditionFailure("Missing bundled fallback font")
            }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }()

    static func nativeFont(size: CGFloat, weight: Font.Weight = .regular) -> NSFont {
        let face = weight == .bold ? "Bold" : weight == .medium || weight == .semibold ? "Medium" : "Regular"
        let chineseFace = face == "Bold" ? "Semibold" : face
        let cascade = [NSFontDescriptor(name: "PingFangSC-\(chineseFace)", size: size)]
        if usesLocalSSENSE, let graphicsFont = localFonts[face == "Regular" ? "Inter" : "Regular"] {
            // Both web fonts have the same internal name ("."). Construct from
            // their outlines directly instead of registering colliding names.
            let descriptor = CTFontDescriptorCreateWithAttributes([kCTFontCascadeListAttribute: cascade] as CFDictionary)
            return CTFontCreateWithGraphicsFont(graphicsFont, size, nil, descriptor) as NSFont
        }
        _ = registered
        let descriptor = NSFontDescriptor(name: "Inter-\(face)", size: size).addingAttributes([.cascadeList: cascade])
        return NSFont(descriptor: descriptor, size: size) ?? NSFont.systemFont(ofSize: size)
    }
}

extension Font {
    static func editorial(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        let font = Font(AppTypography.nativeFont(size: size, weight: weight))
        return design == .monospaced ? font.monospacedDigit() : font
    }
}
