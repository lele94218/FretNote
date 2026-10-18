import XCTest
import CoreText
@testable import FretNoteApp

final class TypographyTests: XCTestCase {
    func testBundledFacesAndChineseFallback() {
        for size in [12.0, 21.0, 42.0] {
            let regular = AppTypography.nativeFont(size: size)
            XCTAssertEqual(regular.fontName, AppTypography.usesLocalSSENSE ? "." : "Inter-Regular")
            XCTAssertEqual(regular.pointSize, size)
            XCTAssertEqual(AppTypography.nativeFont(size: size, weight: .medium).fontName, AppTypography.usesLocalSSENSE ? "." : "Inter-Medium")
            XCTAssertEqual(AppTypography.nativeFont(size: size, weight: .bold).fontName, AppTypography.usesLocalSSENSE ? "." : "Inter-Bold")
            let chinese = CTFontCreateForString(regular as CTFont, "吉他练习" as CFString, CFRange(location: 0, length: 4))
            XCTAssertTrue((CTFontCopyPostScriptName(chinese) as String).hasPrefix("PingFangSC"))
        }
    }
}
