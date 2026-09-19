import XCTest
@testable import FretNoteApp

final class AppearanceTests: XCTestCase {
    @MainActor
    func testPreferencesSurviveRelaunch() throws {
        let suite = "FretNote.appearance-test.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = AppearancePreferences(defaults: defaults)
        XCTAssertEqual(preferences.fontScale, 1.25)
        XCTAssertEqual(preferences.theme, .system)
        preferences.theme = .dark
        preferences.setFontScale(1.5)
        let restored = AppearancePreferences(defaults: defaults)
        XCTAssertEqual(restored.theme, .dark)
        XCTAssertEqual(restored.fontScale, 1.5)
        restored.theme = .system
        XCTAssertNil(AppearancePreferences(defaults: defaults).theme.colorScheme)
    }

    @MainActor
    func testInvalidStoredPreferencesDoNotBreakLayout() throws {
        let suite = "FretNote.appearance-test.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("unknown", forKey: "appearance.theme")
        defaults.set(20.0, forKey: "appearance.fontScale")
        let preferences = AppearancePreferences(defaults: defaults)
        XCTAssertEqual(preferences.theme, .system)
        XCTAssertEqual(preferences.fontScale, 1.75)
        preferences.setFontScale(.nan)
        XCTAssertEqual(preferences.fontScale, 1.75)
        preferences.setFontScale(0)
        XCTAssertEqual(preferences.fontScale, 1)
    }
}
