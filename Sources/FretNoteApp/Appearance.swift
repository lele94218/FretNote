import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String {
        switch self { case .system: return "跟随系统"; case .light: return "浅色"; case .dark: return "深色" }
    }
    var colorScheme: ColorScheme? {
        switch self { case .system: return nil; case .light: return .light; case .dark: return .dark }
    }
}

@MainActor
final class AppearancePreferences: ObservableObject {
    @Published var sidebarVisible = true
    @Published var theme: AppTheme { didSet { defaults.set(theme.rawValue, forKey: "appearance.theme") } }
    @Published private(set) var fontScale: Double
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        theme = AppTheme(rawValue: defaults.string(forKey: "appearance.theme") ?? "system") ?? .system
        let saved = defaults.object(forKey: "appearance.fontScale") as? Double ?? 1.25
        fontScale = saved.isFinite ? min(1.75, max(1, saved)) : 1.25
    }
    func setFontScale(_ value: Double) {
        guard value.isFinite else { return }
        fontScale = min(1.75, max(1, value))
        defaults.set(fontScale, forKey: "appearance.fontScale")
    }
}

private struct InterfaceScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.25
}
extension EnvironmentValues {
    var interfaceScale: CGFloat {
        get { self[InterfaceScaleKey.self] }
        set { self[InterfaceScaleKey.self] = newValue }
    }
}

struct AppPalette {
    let scheme: ColorScheme
    var contrast: ColorSchemeContrast = .standard
    var ink: Color { Color(white: scheme == .dark ? 0.93 : 0.08) }
    var background: Color { Color(white: scheme == .dark ? 0.07 : 1) }
    var muted: Color { Color(white: scheme == .dark ? (contrast == .increased ? 0.85 : 0.65) : (contrast == .increased ? 0.2 : 0.42)) }
    var rule: Color { Color(white: scheme == .dark ? (contrast == .increased ? 0.65 : 0.27) : (contrast == .increased ? 0.4 : 0.88)) }
    var selection: Color { Color(white: scheme == .dark ? 0.18 : 0.94) }
}
