import SwiftUI

/// Keyboard colours. Dark values come from the mockup; light values follow
/// Apple's light keyboard (white letter keys, grey function keys) with
/// darker accents so they stay readable on white.
struct KeyboardTheme {
    let isDark: Bool

    var text: Color { isDark ? .white : .black }
    var secondaryText: Color { isDark ? Color.white.opacity(0.72) : Color.black.opacity(0.62) }
    /// Explanations under corrections: quieter than the corrected text.
    var faintText: Color { isDark ? Color.white.opacity(0.5) : Color.black.opacity(0.42) }
    var tertiaryText: Color { isDark ? Color.white.opacity(0.55) : Color.black.opacity(0.45) }

    var key: Color { isDark ? Color.white.opacity(0.17) : .white }
    var keyPressed: Color { isDark ? Color.white.opacity(0.32) : Color(white: 0.84) }
    var functionKey: Color { isDark ? Color.white.opacity(0.08) : Color(red: 0.67, green: 0.69, blue: 0.73).opacity(0.55) }
    var functionKeyPressed: Color { isDark ? Color.white.opacity(0.2) : .white }
    var keyHighlight: Color { isDark ? Color.white.opacity(0.32) : Color.white.opacity(0.9) }
    var keyShadow: Color { Color.black.opacity(isDark ? 0.35 : 0.22) }

    var divider: Color { isDark ? Color.white.opacity(0.18) : Color.black.opacity(0.14) }
    var card: Color { isDark ? Color.white.opacity(0.1) : Color.white.opacity(0.8) }
    var chip: Color { isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.07) }
    var segmentTrack: Color { isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.07) }
    var segmentSelected: Color { isDark ? Color.white.opacity(0.26) : .white }

    /// Blue for Apply, selected chips and "More natural" (#0a84ff dark, #007aff light).
    var accent: Color { isDark ? Color(red: 10 / 255, green: 132 / 255, blue: 1) : Color(red: 0, green: 122 / 255, blue: 1) }
    /// Changed words in a correction: the iOS blue, as in the system's own suggestions.
    var highlight: Color { accent }
    /// Warnings (no Full Access, proxy errors).
    var warning: Color { isDark ? Color(red: 1, green: 179 / 255, blue: 64 / 255) : Color(red: 201 / 255, green: 92 / 255, blue: 0) }
    /// Second tone of two-tone icons (the language mark next to the settings icon).
    var iconSecondary: Color { isDark ? Color.white.opacity(0.42) : Color.black.opacity(0.32) }
    /// "Looks natural" tick (#30d158 dark, #248a3d light).
    var good: Color { isDark ? Color(red: 48 / 255, green: 209 / 255, blue: 88 / 255) : Color(red: 36 / 255, green: 138 / 255, blue: 61 / 255) }

    /// Only used to frame snapshots; on a device the system draws the keyboard background.
    var snapshotPlatter: Color { isDark ? Color(red: 0.2, green: 0.2, blue: 0.21) : Color(red: 0.84, green: 0.85, blue: 0.87) }
}
