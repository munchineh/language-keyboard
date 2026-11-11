import Foundation

/// Korean word completions from a frequency list (most frequent first).
///
/// Matching is done on decomposed jamo, so a half-typed syllable still matches:
/// 안녀 → 안녕, and 갑 → 가방 (the final ㅂ may become the next syllable's initial).
final class KoreanLexicon {
    private let words: [String]
    private let keys: [[UInt32]]

    init(words: [String]) {
        self.words = words
        self.keys = words.map { Self.jamoKey($0) }
    }

    convenience init?(url: URL) {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        self.init(words: text.split(separator: "\n").map(String.init))
    }

    /// Up to `limit` words that start with `prefix` and are longer than it.
    func completions(for prefix: String, limit: Int = 3) -> [String] {
        guard !prefix.isEmpty else { return [] }
        var prefixes = [Self.jamoKey(prefix)]
        if let alternate = Self.finalAsInitial(prefix) { prefixes.append(Self.jamoKey(alternate)) }
        var out: [String] = []
        for (i, key) in keys.enumerated() where words[i] != prefix && words[i].count >= prefix.count {
            if prefixes.contains(where: { key.starts(with: $0) }) {
                out.append(words[i])
                if out.count == limit { break }
            }
        }
        return out
    }

    /// Unicode scalars of the canonical decomposition, with lone compatibility
    /// consonants (ㄱ) mapped to initial jamo (ᄀ) so they can prefix-match.
    static func jamoKey(_ s: String) -> [UInt32] {
        var out: [UInt32] = []
        for scalar in s.decomposedStringWithCanonicalMapping.unicodeScalars {
            if let index = HangulComposer.choseong.firstIndex(of: Character(scalar)) {
                out.append(0x1100 + UInt32(index))
            } else {
                out.append(scalar.value)
            }
        }
        return out
    }

    /// 갑 → 가ᄇ: the same text with its last final consonant read as the next initial.
    static func finalAsInitial(_ s: String) -> String? {
        guard let last = s.unicodeScalars.last, (0xAC00...0xD7A3).contains(last.value) else { return nil }
        let offset = Int(last.value - 0xAC00)
        let jong = offset % 28
        guard jong > 0, let final = HangulComposer.jongseong[jong] else { return nil }
        // A double final keeps its first part: 값 → 갑 + ᄉ.
        let (stays, moves): (Character?, Character) = HangulComposer.finalSplits[final].map { ($0.0, $0.1) } ?? (nil, final)
        guard let initial = HangulComposer.choseong.firstIndex(of: moves) else { return nil }
        let stayIndex = stays.flatMap { HangulComposer.jongseong.firstIndex(of: $0) } ?? 0
        let base = UnicodeScalar(0xAC00 + offset - jong + stayIndex)!
        var result = String(s.unicodeScalars.dropLast())
        result.unicodeScalars.append(base)
        result.unicodeScalars.append(UnicodeScalar(0x1100 + initial)!)
        return result
    }
}

/// Pinyin to characters, from a frequency list of `pinyin<TAB>simplified<TAB>traditional`.
final class PinyinLexicon {
    struct Candidate: Equatable, Hashable {
        let text: String
        /// Letters of the pinyin buffer this candidate uses up.
        let consumed: Int
    }

    private struct Entry {
        let pinyin: String
        let simplified: String
        let traditional: String
    }

    private let entries: [Entry]
    private var exact: [String: [Int]] = [:]

    init(lines: [Substring]) {
        var list: [Entry] = []
        list.reserveCapacity(lines.count)
        for line in lines {
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard parts.count >= 3 else { continue }
            list.append(Entry(pinyin: String(parts[0]), simplified: String(parts[1]), traditional: String(parts[2])))
        }
        entries = list
        for (i, e) in list.enumerated() { exact[e.pinyin, default: []].append(i) }
    }

    convenience init?(url: URL) {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        self.init(lines: text.split(separator: "\n"))
    }

    /// Candidates for the typed pinyin: whole-buffer matches first, then words
    /// for the longest leading part, then a few longer words it starts.
    func candidates(for buffer: String, script: ChineseScript, limit: Int = 30) -> [Candidate] {
        let b = buffer.lowercased()
        guard !b.isEmpty else { return [] }
        var out: [Candidate] = []
        var seen = Set<String>()
        func add(_ i: Int, _ consumed: Int) {
            let text = script == .simplified ? entries[i].simplified : entries[i].traditional
            if seen.insert(text).inserted { out.append(Candidate(text: text, consumed: consumed)) }
        }
        for i in exact[b] ?? [] { add(i, b.count) }
        // Words for the longest leading part (zhongguo|ren → 中國), then shorter parts.
        var length = b.count - 1
        while length > 0 && out.count < limit {
            let part = String(b.prefix(length))
            for i in exact[part] ?? [] where out.count < limit { add(i, length) }
            length -= 1
        }
        // A few longer words the buffer starts (ruanjian → 軟體開發), last.
        var completions = 0
        for (i, e) in entries.enumerated() where e.pinyin.count > b.count && e.pinyin.hasPrefix(b) {
            add(i, b.count)
            completions += 1
            if completions == 3 { break }
        }
        return Array(out.prefix(limit))
    }
}

/// Emoji grouped as in Unicode's emoji-test.txt.
struct EmojiCatalog {
    struct Group: Identifiable {
        let name: String
        let emoji: [String]
        var id: String { name }
        /// Icon for the category bar.
        var symbol: String {
            switch name {
            case "Smileys & Emotion": return "face.smiling"
            case "People & Body": return "hand.wave"
            case "Animals & Nature": return "pawprint"
            case "Food & Drink": return "fork.knife"
            case "Travel & Places": return "car"
            case "Activities": return "soccerball"
            case "Objects": return "lightbulb"
            case "Symbols": return "heart"
            case "Flags": return "flag"
            default: return "circle"
            }
        }
    }

    let groups: [Group]

    init(text: String) {
        groups = text.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "\t", maxSplits: 1)
            guard parts.count == 2 else { return nil }
            return Group(name: String(parts[0]), emoji: parts[1].split(separator: " ").map(String.init))
        }
    }

    init?(url: URL) {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        self.init(text: text)
    }
}
