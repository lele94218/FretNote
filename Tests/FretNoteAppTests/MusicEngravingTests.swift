import XCTest
import CoreText
@testable import FretNoteApp

final class MusicEngravingTests: XCTestCase {
    func testBundledMusicFontAndOutlines() {
        XCTAssertEqual(CTFontCopyPostScriptName(MusicEngraving.font) as String, "Bravura")
        for outline in [MusicEngraving.head, MusicEngraving.clef, MusicEngraving.sharp,
                        MusicEngraving.natural, MusicEngraving.upStem, MusicEngraving.downStem] {
            XCTAssertFalse(outline.isEmpty)
            XCTAssertGreaterThan(outline.boundingRect.width, 0)
            XCTAssertGreaterThan(outline.boundingRect.height, 0)
        }
        XCTAssertEqual(MusicEngraving.head.boundingRect.height, MusicEngraving.space, accuracy: 0.2)
        XCTAssertEqual(MusicEngraving.upStem.boundingRect.minY, -49, accuracy: 0.01)
        XCTAssertEqual(MusicEngraving.downStem.boundingRect.maxY, 49, accuracy: 0.01)
    }
}
