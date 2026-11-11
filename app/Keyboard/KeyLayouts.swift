import Foundation

/// What a key does.
enum KeyKind: Hashable {
    /// Inserts text. `shifted` is used while shift is on (ㅂ → ㅃ, a → A).
    case text(String, shifted: String?)
    case shift
    case delete
    case numbers
    case letters
    case languageToggle
    case space
    case returnKey
    case nextKeyboard
}

enum KeyWidth: Hashable {
    case flex
    case fixed(CGFloat)
}

struct Key: Identifiable, Hashable {
    let id: String
    let kind: KeyKind
    let width: KeyWidth
    /// Extra space before/after (shift and delete sit slightly apart from the letters).
    var leadingGap: CGFloat = 0
    var trailingGap: CGFloat = 0

    static func text(_ s: String, _ shifted: String? = nil) -> Key {
        Key(id: "t-" + s, kind: .text(s, shifted: shifted), width: .flex)
    }
}

struct KeyRow: Identifiable, Hashable {
    let id: Int
    let keys: [Key]
    /// Horizontal inset of the whole row (the second Korean row is indented).
    let inset: CGFloat
}

enum KeyboardPage: Hashable {
    case letters
    case numbers
}

/// Dimensions from the mockup (390pt-wide iPhone): 44pt keys, 6pt gaps, 12pt row gaps.
enum KeyMetrics {
    static let keyHeight: CGFloat = 44
    static let horizontalGap: CGFloat = 6
    static let verticalGap: CGFloat = 12
    static let rowHeight: CGFloat = keyHeight + verticalGap
    static let cornerRadius: CGFloat = 10
    static let barHeight: CGFloat = 46
}

enum KeyLayouts {
    static func rows(language: KeyboardLanguage, page: KeyboardPage, showGlobe: Bool) -> [KeyRow] {
        switch page {
        case .numbers: return numbers(language: language, showGlobe: showGlobe)
        case .letters:
            switch language {
            case .korean: return korean(showGlobe: showGlobe)
            case .chinese: return qwerty(showGlobe: showGlobe)
            }
        }
    }

    // Dubeolsik, as on Apple's Korean keyboard.
    private static func korean(showGlobe: Bool) -> [KeyRow] {
        let shifted: [String: String] = ["ㅂ": "ㅃ", "ㅈ": "ㅉ", "ㄷ": "ㄸ", "ㄱ": "ㄲ", "ㅅ": "ㅆ", "ㅐ": "ㅒ", "ㅔ": "ㅖ"]
        func row(_ s: String) -> [Key] { s.map { Key.text(String($0), shifted[String($0)]) } }
        return [
            KeyRow(id: 0, keys: row("ㅂㅈㄷㄱㅅㅛㅕㅑㅐㅔ"), inset: 4),
            KeyRow(id: 1, keys: row("ㅁㄴㅇㄹㅎㅗㅓㅏㅣ"), inset: 22),
            KeyRow(id: 2, keys: [shiftKey] + row("ㅋㅌㅊㅍㅠㅜㅡ") + [deleteKey], inset: 4),
            bottomRow(left: Key(id: "numbers", kind: .numbers, width: .fixed(60)), showGlobe: showGlobe),
        ]
    }

    // Pinyin letters. RIME will turn these into characters (chat C).
    private static func qwerty(showGlobe: Bool) -> [KeyRow] {
        func row(_ s: String) -> [Key] { s.map { Key.text(String($0), String($0).uppercased()) } }
        return [
            KeyRow(id: 0, keys: row("qwertyuiop"), inset: 4),
            KeyRow(id: 1, keys: row("asdfghjkl"), inset: 22),
            KeyRow(id: 2, keys: [shiftKey] + row("zxcvbnm") + [deleteKey], inset: 4),
            bottomRow(left: Key(id: "numbers", kind: .numbers, width: .fixed(60)), showGlobe: showGlobe),
        ]
    }

    private static func numbers(language: KeyboardLanguage, showGlobe: Bool) -> [KeyRow] {
        func row(_ items: [String]) -> [Key] { items.map { Key.text($0) } }
        let currency = language == .korean ? "₩" : "¥"
        let punctuation: [String] = language == .korean
            ? [".", ",", "?", "!", "'", "~", "^"]
            : ["。", "，", "？", "！", "、", "～", "…"]
        return [
            KeyRow(id: 0, keys: row(["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]), inset: 4),
            KeyRow(id: 1, keys: row(["-", "/", ":", ";", "(", ")", currency, "&", "@", "\""]), inset: 4),
            KeyRow(id: 2, keys: [Key(id: "spacer", kind: .text("", shifted: nil), width: .fixed(46), trailingGap: 8)]
                   + row(punctuation) + [deleteKey], inset: 4),
            bottomRow(left: Key(id: "letters", kind: .letters, width: .fixed(60)), showGlobe: showGlobe),
        ]
    }

    private static let shiftKey = Key(id: "shift", kind: .shift, width: .fixed(46), trailingGap: 8)
    private static let deleteKey = Key(id: "delete", kind: .delete, width: .fixed(46), leadingGap: 8)

    private static func bottomRow(left: Key, showGlobe: Bool) -> KeyRow {
        var keys = [left]
        // On Face ID iPhones the system draws the globe below the keyboard.
        if showGlobe { keys.append(Key(id: "globe", kind: .nextKeyboard, width: .fixed(44))) }
        // The mockup's emoji slot: third-party keyboards can't open the emoji
        // keyboard, so it switches between the keyboard's own languages instead.
        keys.append(Key(id: "lang", kind: .languageToggle, width: .fixed(60)))
        keys.append(Key(id: "space", kind: .space, width: .flex))
        keys.append(Key(id: "return", kind: .returnKey, width: .fixed(104)))
        return KeyRow(id: 3, keys: keys, inset: 4)
    }
}
