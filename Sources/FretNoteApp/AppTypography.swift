import SwiftUI
import CoreText

/// Inter is an OFL-licensed alternative, not SSENSE's proprietary custom Favorit.
/// Use the same faces in SwiftUI, Canvas labels, and native popup menus.
enum AppTypography {
    private static let registered: Void = {
        let resources: Bundle
        if let url = Bundle.main.url(forResource: "FretNote_FretNoteApp", withExtension: "bundle"),
           let bundle = Bundle(url: url) {
            resources = bundle
        } else {
            resources = Bundle.module
        }
        for face in ["Regular", "Medium", "Bold"] {
            guard let url = resources.url(forResource: "Inter-\(face)", withExtension: "ttf") else {
                preconditionFailure("Missing bundled Inter font")
            }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }()

    static func nativeFont(size: CGFloat, weight: Font.Weight = .regular) -> NSFont {
        _ = registered
        let face = weight == .bold ? "Bold" : weight == .medium || weight == .semibold ? "Medium" : "Regular"
        let chineseFace = face == "Bold" ? "Semibold" : face
        let descriptor = NSFontDescriptor(name: "Inter-\(face)", size: size).addingAttributes([
            .cascadeList: [NSFontDescriptor(name: "PingFangSC-\(chineseFace)", size: size)]
        ])
        return NSFont(descriptor: descriptor, size: size) ?? NSFont.systemFont(ofSize: size)
    }
}

extension Font {
    static func editorial(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        let font = Font(AppTypography.nativeFont(size: size, weight: weight))
        // Keep changing meter values stable without changing the typeface.
        return design == .monospaced ? font.monospacedDigit() : font
    }
}
