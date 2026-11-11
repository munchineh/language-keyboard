import Foundation

/// Character-level diff used to highlight what a correction changed
/// (선생님한테 줬어 → 선생님께 드렸어 highlights 께 and 드렸어).
enum TextDiff {
    struct Segment: Equatable {
        var text: String
        var changed: Bool
    }

    /// Segments of `new`, marking the parts that aren't in `old`.
    static func segments(old: String, new: String) -> [Segment] {
        let a = Array(old), b = Array(new)
        let n = a.count, m = b.count
        if n == 0 { return b.isEmpty ? [] : [Segment(text: new, changed: true)] }
        if m == 0 { return [] }
        // Longest common subsequence table (texts are short: ≤ 1000 chars).
        var lcs = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in stride(from: n - 1, through: 0, by: -1) {
            for j in stride(from: m - 1, through: 0, by: -1) {
                lcs[i][j] = a[i] == b[j] ? lcs[i + 1][j + 1] + 1 : max(lcs[i + 1][j], lcs[i][j + 1])
            }
        }
        var flags: [Bool] = [] // per character of `new`: changed?
        var i = 0, j = 0
        while j < m {
            if i < n && a[i] == b[j] {
                flags.append(false); i += 1; j += 1
            } else if i < n && lcs[i + 1][j] >= lcs[i][j + 1] {
                i += 1
            } else {
                flags.append(true); j += 1
            }
        }
        return merge(b, flags)
    }

    /// Join neighbouring characters with the same flag into one segment.
    private static func merge(_ chars: [Character], _ flags: [Bool]) -> [Segment] {
        var out: [Segment] = []
        for (c, changed) in zip(chars, flags) {
            if var last = out.last, last.changed == changed {
                last.text.append(c)
                out[out.count - 1] = last
            } else {
                out.append(Segment(text: String(c), changed: changed))
            }
        }
        return out
    }

    static func changeCount(old: String, new: String) -> Int {
        segments(old: old, new: new).filter(\.changed).count
    }
}
