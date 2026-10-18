import XCTest
import SwiftUI
@testable import FretNoteApp

final class LocalizationTests: XCTestCase {
    @MainActor
    func testLanguagePersistsSeparatelyFromPractice() throws {
        let name = "FretNote.language-tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppearancePreferences(defaults: defaults)
        XCTAssertEqual(settings.language, .chinese)
        settings.language = .english
        XCTAssertEqual(AppearancePreferences(defaults: defaults).language, .english)
        settings.language = .chinese
        XCTAssertEqual(AppearancePreferences(defaults: defaults).language, .chinese)
    }

    func testEnglishFeedbackAndLegacyRecords() {
        let examples = [
            "听到 A4，再试一次。": "Heard A4. Try again.",
            "第 2 / 10 题 · 首次正确 80%": "Question 2 / 10 · First try 80%",
            "琶音练习 · 137": "Arpeggios · 137",
            "六根弦 · 3–6 品 · 自然音": "All strings · Frets 3–6 · Natural notes",
            "432 弦": "Strings 432",
            "1、2 弦 · 0–21 品 · 全部音": "Strings 1, 2 · Frets 0–21 · All notes",
            "3 音 · 首次正确 50% · 平均 1.5 秒": "3 notes · First try 50% · Avg 1.5 s",
            "大三": "Major"
        ]
        for (source, expected) in examples {
            XCTAssertEqual(AppLanguage.english.translate(source), expected, source)
            XCTAssertEqual(AppLanguage.chinese.translate(source), source)
        }
        XCTAssertEqual(AppLanguage.english.translate("Scarlett 2i2"), "Scarlett 2i2")
    }

    func testEveryCatalogTemplateResolvesWithoutChinese() {
        for template in TranslationCatalog.entries.keys where template != "语言 / Language" {
            var sample = template
            for index in 0..<10 { sample = sample.replacingOccurrences(of: "{\(index)}", with: String(index + 1)) }
            let translated = AppLanguage.english.translate(sample)
            XCTAssertNil(translated.range(of: "[一-鿿]", options: .regularExpression), "\(sample) → \(translated)")
        }
    }
}
