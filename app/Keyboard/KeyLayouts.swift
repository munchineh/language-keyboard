import Foundation

/// What a key does.
enum KeyKind: Hashable {
    /// Inserts text. `shifted` is used while shift is on (ㅂ → ㅃ, a → A).
    case text(String, shifted: String?)
    case shift
    case delete
    case numbers
    case letters
    case emoji
    /// Only while typing into a settings field: switches Hangul ↔ ABC.
    case fieldLayoutToggle
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
    var leadingGap: CGFloat = 0
    var trailingGap: CGFloat = 0

    static func text(_ s: String, _ shifted: String? = nil) -> Key {
        Key(id: "t-" + s, kind: .text(s, shifted: shifted), width: .flex)
    }
}

struct KeyRow: Identifiable, Hashable {
    let id: Int
    let keys: [Key]
    /// Horizontal inset of the whole row (the second letter row is indented).
    let inset: CGFloat
}

enum KeyboardPage: Hashable {
    case letters
    case numbers
    case emoji
}

/// Which letters the letter page shows.
enum LetterLayout: Hashable {
    case hangul
    case latin
}

/// Dimensions from the mockup (390pt-wide iPhone): 44pt keys, 6pt gaps, 12pt row gaps.
enum KeyMetrics {
    static let keyHeight: CGFloat = 44
    static let horizontalGap: CGFloat = 6
    static let verticalGap: CGFloat = 12
    static let rowHeight: CGFloat = keyHeight + verticalGap
    static let cornerRadius: CGFloat = 10
    static let barHeight: CGFloat = 46
    /// Space between the keyboard's edge and the result card, on every side.
    static let cardMargin: CGFloat = 6
    /// Top corner radius of the keyboard background (mockup: 30).
    static let keyboardRadius: CGFloat = 30
    /// Concentric with the keyboard's corners.
    static var cardRadius: CGFloat { keyboardRadius - cardMargin }
    /// Bar plus four key rows. Settings and emoji use the same height.
    static let bodyHeight: CGFloat = barHeight + 6 + rowHeight * 4 + 4
}

enum KeyLayouts {
    /// - Parameter editingField: true while typing into a settings field (shows the ABC/한 toggle).
    static func rows(letters: LetterLayout, page: KeyboardPage, language: KeyboardLanguage,
                     showGlobe: Bool, editingField: Bool) -> [KeyRow] {
        let bottom = bottomRow(page: page, letters: letters, language: language, showGlobe: showGlobe, editingField: editingField)
        switch page {
        case .numbers: return numbers(language: language) + [bottom]
        case .letters, .emoji: return (letters == .hangul ? hangul() : latin()) + [bottom]
        }
    }

    // Dubeolsik, as on Apple's Korean keyboard.
    private static func hangul() -> [KeyRow] {
        let shifted: [String: String] = ["ㅂ": "ㅃ", "ㅈ": "ㅉ", "ㄷ": "ㄸ", "ㄱ": "ㄲ", "ㅅ": "ㅆ", "ㅐ": "ㅒ", "ㅔ": "ㅖ"]
        func row(_ s: String) -> [Key] { s.map { Key.text(String($0), shifted[String($0)]) } }
        return [
            KeyRow(id: 0, keys: row("ㅂㅈㄷㄱㅅㅛㅕㅑㅐㅔ"), inset: 4),
            KeyRow(id: 1, keys: row("ㅁㄴㅇㄹㅎㅗㅓㅏㅣ"), inset: 22),
            KeyRow(id: 2, keys: [shiftKey] + row("ㅋㅌㅊㅍㅠㅜㅡ") + [deleteKey], inset: 4),
        ]
    }

    // Pinyin for Chinese, and English in settings fields.
    private static func latin() -> [KeyRow] {
        func row(_ s: String) -> [Key] { s.map { Key.text(String($0), String($0).uppercased()) } }
        return [
            KeyRow(id: 0, keys: row("qwertyuiop"), inset: 4),
            KeyRow(id: 1, keys: row("asdfghjkl"), inset: 22),
            KeyRow(id: 2, keys: [shiftKey] + row("zxcvbnm") + [deleteKey], inset: 4),
        ]
    }

    private static func numbers(language: KeyboardLanguage) -> [KeyRow] {
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
        ]
    }

    private static let shiftKey = Key(id: "shift", kind: .shift, width: .fixed(46), trailingGap: 8)
    private static let deleteKey = Key(id: "delete", kind: .delete, width: .fixed(46), leadingGap: 8)

    private static func bottomRow(page: KeyboardPage, letters: LetterLayout, language: KeyboardLanguage,
                                  showGlobe: Bool, editingField: Bool) -> KeyRow {
        var keys = [page == .numbers
            ? Key(id: "letters", kind: .letters, width: .fixed(60))
            : Key(id: "numbers", kind: .numbers, width: .fixed(60))]
        if editingField && language == .korean {
            keys.append(Key(id: "fieldToggle", kind: .fieldLayoutToggle, width: .fixed(60)))
        } else if !editingField {
            keys.append(Key(id: "emoji", kind: .emoji, width: .fixed(60)))
        }
        // On Face ID iPhones the system draws the globe below the keyboard.
        if showGlobe { keys.append(Key(id: "globe", kind: .nextKeyboard, width: .fixed(44))) }
        keys.append(Key(id: "space", kind: .space, width: .flex))
        keys.append(Key(id: "return", kind: .returnKey, width: .fixed(104)))
        return KeyRow(id: 3, keys: keys, inset: 4)
    }
}
