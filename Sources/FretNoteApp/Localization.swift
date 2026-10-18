import SwiftUI

/// Translate at the presentation boundary so saved session identifiers remain stable.
/// Templates also cover Chinese records written by earlier app versions.
enum AppLanguage: String, CaseIterable, Identifiable {
    case chinese = "zh-Hans", english = "en"
    var id: String { rawValue }
    var title: String { self == .chinese ? "简体中文" : "English" }
    var locale: Locale { Locale(identifier: rawValue) }
    func translate(_ text: String) -> String {
        self == .english ? TranslationCatalog.english(text) : text
    }
}

private struct AppLanguageKey: EnvironmentKey {
    static let defaultValue = AppLanguage.chinese
}
extension EnvironmentValues {
    var appLanguage: AppLanguage {
        get { self[AppLanguageKey.self] }
        set { self[AppLanguageKey.self] = newValue }
    }
}
protocol Localizable {
    var language: AppLanguage { get }
}
extension Localizable {
    func L(_ text: String) -> String { language.translate(text) }
}

enum TranslationCatalog {
    static let entries: [String: String] = {
        let resources: Bundle
        if let url = Bundle.main.url(forResource: "FretNote_FretNoteApp", withExtension: "bundle"),
           let bundle = Bundle(url: url) { resources = bundle }
        else { resources = Bundle.module }
        let url = resources.url(forResource: "English", withExtension: "json")!
        return try! JSONDecoder().decode([String: String].self, from: Data(contentsOf: url))
    }()
    private struct Rule {
        let regex: NSRegularExpression
        let replacement: String
    }
    private static let rules: [Rule] = entries.keys.filter { $0.contains("{0}") }.sorted {
        // Specific messages must precede generic prefixes, such as "Heard …".
        let lhs = $0.replacingOccurrences(of: "\\{[0-9]+\\}", with: "", options: .regularExpression).count
        let rhs = $1.replacingOccurrences(of: "\\{[0-9]+\\}", with: "", options: .regularExpression).count
        return lhs == rhs ? $0 < $1 : lhs > rhs
    }.map { key in
        var pattern = NSRegularExpression.escapedPattern(for: key)
        for index in 0..<10 {
            pattern = pattern.replacingOccurrences(of: NSRegularExpression.escapedPattern(for: "{\(index)}"), with: "(.*?)")
        }
        return Rule(regex: try! NSRegularExpression(pattern: "^" + pattern + "$", options: .dotMatchesLineSeparators), replacement: entries[key]!)
    }
    static func english(_ text: String) -> String {
        translate(text, depth: 0).replacingOccurrences(of: "、", with: ", ")
    }
    private static func translate(_ text: String, depth: Int) -> String {
        guard depth < 8, text.range(of: "[一-鿿]", options: .regularExpression) != nil else { return text }
        if let value = entries[text] { return value }
        let range = NSRange(text.startIndex..., in: text)
        for rule in rules {
            guard let match = rule.regex.firstMatch(in: text, range: range) else { continue }
            var result = rule.replacement
            for index in (1..<match.numberOfRanges).reversed() {
                guard let capture = Range(match.range(at: index), in: text) else { continue }
                result = result.replacingOccurrences(of: "{\(index - 1)}", with: translate(String(text[capture]), depth: depth + 1))
            }
            return result
        }
        // Older records store scope/mode as joined Chinese labels. Localize the
        // parts without mutating the archive or translating external error text.
        for separator in [" · ", "；", "，"] where text.contains(separator) {
            return text.components(separatedBy: separator).map { translate($0, depth: depth + 1) }
                .joined(separator: separator == " · " ? separator : "; ")
        }
        return text
    }
}
