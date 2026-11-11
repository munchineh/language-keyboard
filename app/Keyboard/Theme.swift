import SwiftUI

/// Colours from the mockup (dark) with a light-mode counterpart.
struct KeyboardTheme {
    let isDark: Bool

    var text: Color { isDark ? .white : .black }
    var secondaryText: Color { isDark ? Color.white.opacity(0.72) : Color.black.opacity(0.6) }
    var tertiaryText: Color { isDark ? Color.white.opacity(0.55) : Color.black.opacity(0.45) }
    var key: Color { isDark ? Color.white.opacity(0.17) : .white }
    var keyPressed: Color { isDark ? Color.white.opacity(0.32) : Color(white: 0.82) }
    var functionKey: Color { isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.12) }
    var functionKeyPressed: Color { isDark ? Color.white.opacity(0.2) : .white }
    var keyHighlight: Color { isDark ? Color.white.opacity(0.32) : Color.white.opacity(0.8) }
    var keyShadow: Color { Color.black.opacity(isDark ? 0.35 : 0.25) }
    var divider: Color { isDark ? Color.white.opacity(0.18) : Color.black.opacity(0.15) }
    var card: Color { isDark ? Color.white.opacity(0.1) : Color.white.opacity(0.75) }
    var chip: Color { isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.06) }
    var segmentTrack: Color { isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.06) }
    var segmentSelected: Color { isDark ? Color.white.opacity(0.26) : .white }

    static let accent = Color(red: 10 / 255, green: 132 / 255, blue: 1)        // #0a84ff
    static let fixHighlight = Color(red: 1, green: 179 / 255, blue: 64 / 255)    // #ffb340
    static let good = Color(red: 48 / 255, green: 209 / 255, blue: 88 / 255)     // #30d158
}
