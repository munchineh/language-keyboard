import Foundation

/// Dubeolsik (2-beolsik) Hangul composition.
///
/// Feed it compatibility jamo (ㄱ, ㅏ, ...) one key at a time. Each call returns
/// the text that is now final (`committed`) and the syllable still being built
/// (`composing`). The keyboard replaces the previous `composing` text in the
/// document with `committed + composing`.
struct HangulComposer {
    struct Output: Equatable {
        var committed: String
        var composing: String
    }

    // Compatibility jamo tables in Unicode syllable order.
    static let choseong: [Character] = Array("ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ")
    static let jungseong: [Character] = Array("ㅏㅐㅑㅒㅓㅔㅕㅖㅗㅘㅙㅚㅛㅜㅝㅞㅟㅠㅡㅢㅣ")
    static let jongseong: [Character?] = [nil] + Array("ㄱㄲㄳㄴㄵㄶㄷㄹㄺㄻㄼㄽㄾㄿㅀㅁㅂㅄㅅㅆㅇㅈㅊㅋㅌㅍㅎ").map { Optional($0) }

    static let vowelPairs: [String: Character] = [
        "ㅗㅏ": "ㅘ", "ㅗㅐ": "ㅙ", "ㅗㅣ": "ㅚ",
        "ㅜㅓ": "ㅝ", "ㅜㅔ": "ㅞ", "ㅜㅣ": "ㅟ",
        "ㅡㅣ": "ㅢ",
    ]
    static let finalPairs: [String: Character] = [
        "ㄱㅅ": "ㄳ", "ㄴㅈ": "ㄵ", "ㄴㅎ": "ㄶ",
        "ㄹㄱ": "ㄺ", "ㄹㅁ": "ㄻ", "ㄹㅂ": "ㄼ", "ㄹㅅ": "ㄽ",
        "ㄹㅌ": "ㄾ", "ㄹㅍ": "ㄿ", "ㄹㅎ": "ㅀ", "ㅂㅅ": "ㅄ",
    ]
    /// Split a double final back into (stays, moves to the next syllable).
    static let finalSplits: [Character: (Character, Character)] = {
        var map: [Character: (Character, Character)] = [:]
        for (pair, combined) in finalPairs {
            let parts = Array(pair)
            map[combined] = (parts[0], parts[1])
        }
        return map
    }()

    static func isConsonant(_ c: Character) -> Bool { choseong.contains(c) || finalSplits[c] != nil }
    static func isVowel(_ c: Character) -> Bool { jungseong.contains(c) }
    static func isJamo(_ c: Character) -> Bool { isConsonant(c) || isVowel(c) }

    private var cho: Character?
    private var jung: Character?
    private var jong: Character?
    /// Keys that built the current syllable, for jamo-by-jamo backspace.
    private var keys: [Character] = []

    var isComposing: Bool { cho != nil || jung != nil }
    /// True when the syllable is a lone consonant or lone vowel (not a full syllable yet).
    var isIncomplete: Bool { (cho == nil) != (jung == nil) }
    var composing: String { Self.render(cho: cho, jung: jung, jong: jong) }

    init() {}

    /// Type one jamo.
    mutating func input(_ c: Character) -> Output {
        if Self.isVowel(c) { return inputVowel(c) }
        if Self.isConsonant(c) { return inputConsonant(c) }
        // Anything else ends the syllable and is committed as is.
        let done = commit()
        return Output(committed: done + String(c), composing: "")
    }

    /// Backspace. Returns nil when nothing is composing (the keyboard should
    /// delete a character from the document instead).
    mutating func backspace() -> Output? {
        guard isComposing else { return nil }
        var remaining = keys
        remaining.removeLast()
        reset()
        for k in remaining { _ = input(k) }
        return Output(committed: "", composing: composing)
    }

    /// Finish the current syllable (space, punctuation, cursor move, language switch).
    mutating func commit() -> String {
        let text = composing
        reset()
        return text
    }

    mutating func reset() {
        cho = nil; jung = nil; jong = nil; keys = []
    }

    // MARK: - Private

    private mutating func inputConsonant(_ c: Character) -> Output {
        if cho == nil && jung == nil {
            cho = c; keys = [c]
            return Output(committed: "", composing: composing)
        }
        if jung == nil {
            // Consonant after a lone consonant: commit and start over.
            let done = commit()
            cho = c; keys = [c]
            return Output(committed: done, composing: composing)
        }
        if cho == nil {
            // Lone vowel, then a consonant: start a new syllable.
            let done = commit()
            cho = c; keys = [c]
            return Output(committed: done, composing: composing)
        }
        if let current = jong {
            if let combined = Self.finalPairs[String([current, c])] {
                jong = combined; keys.append(c)
                return Output(committed: "", composing: composing)
            }
            let done = commit()
            cho = c; keys = [c]
            return Output(committed: done, composing: composing)
        }
        if Self.jongseong.contains(c) {
            jong = c; keys.append(c)
            return Output(committed: "", composing: composing)
        }
        // ㄸ ㅃ ㅉ can't be finals.
        let done = commit()
        cho = c; keys = [c]
        return Output(committed: done, composing: composing)
    }

    private mutating func inputVowel(_ v: Character) -> Output {
        if cho == nil && jung == nil {
            jung = v; keys = [v]
            return Output(committed: "", composing: composing)
        }
        if jung == nil {
            jung = v; keys.append(v)
            return Output(committed: "", composing: composing)
        }
        if let final = jong {
            // The final consonant moves to the new syllable: 각 + ㅏ → 가가.
            let moved: Character
            if let (stays, moves) = Self.finalSplits[final] {
                jong = stays
                moved = moves
            } else {
                jong = nil
                moved = final
            }
            let done = composing
            reset()
            cho = moved; jung = v; keys = [moved, v]
            return Output(committed: done, composing: composing)
        }
        if let current = jung, let combined = Self.vowelPairs[String([current, v])] {
            jung = combined; keys.append(v)
            return Output(committed: "", composing: composing)
        }
        let done = commit()
        jung = v; keys = [v]
        return Output(committed: done, composing: composing)
    }

    static func render(cho: Character?, jung: Character?, jong: Character?) -> String {
        guard let cho, let jung,
              let l = choseong.firstIndex(of: cho),
              let v = jungseong.firstIndex(of: jung) else {
            return [cho, jung, jong].compactMap { $0 }.map(String.init).joined()
        }
        let t = jongseong.firstIndex(of: jong) ?? 0
        let scalar = UnicodeScalar(0xAC00 + (l * 21 + v) * 28 + t)!
        return String(Character(scalar))
    }
}
