import SwiftUI

/// Rocksmith's standard six-string mapping, indexed by physical guitar string.
enum GuitarStringPalette {
    static func color(_ string: Int) -> Color {
        switch string {
        case 6: return Color(red: 1.00, green: 0.25, blue: 0.28) // low E — red
        case 5: return Color(red: 1.00, green: 0.85, blue: 0.15) // A — yellow
        case 4: return Color(red: 0.15, green: 0.65, blue: 1.00) // D — blue
        case 3: return Color(red: 1.00, green: 0.52, blue: 0.12) // G — orange
        case 2: return Color(red: 0.30, green: 0.90, blue: 0.22) // B — green
        case 1: return Color(red: 0.78, green: 0.37, blue: 1.00) // high E — purple
        default: return .gray
        }
    }
}
