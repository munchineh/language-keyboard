import Foundation

/// Languages the keyboard can type and check. Matches the proxy's `lang` values.
enum KeyboardLanguage: String, Codable, CaseIterable, Identifiable, CodingKeyRepresentable {
    case korean = "ko"
    case chinese = "zh"

    var id: String { rawValue }
    var name: String {
        switch self {
        case .korean: return "한국어"
        case .chinese: return "中文"
        }
    }
    /// One-character mark shown next to the settings icon.
    var badge: String {
        switch self {
        case .korean: return "한"
        case .chinese: return "中"
        }
    }
}

enum SpeechLevel: String, Codable, CaseIterable, Identifiable {
    case banmal, haeyo, hapsyo
    var id: String { rawValue }
    var label: String {
        switch self {
        case .banmal: return "반말"
        case .haeyo: return "해요체"
        case .hapsyo: return "합쇼체"
        }
    }
}

enum RelativeAge: String, Codable, CaseIterable, Identifiable {
    case older, same, younger
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

/// Listener's or user's gender. `unset` means the check doesn't assume one.
enum Gender: String, Codable, CaseIterable, Identifiable {
    case male, female, unset
    var id: String { rawValue }
    var label: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .unset: return "Not set"
        }
    }
    var short: String {
        switch self {
        case .male: return "M"
        case .female: return "F"
        case .unset: return "–"
        }
    }
}

/// Which rewrite the card offers when correct text sounds stiff. Only one is shown.
enum RephraseStyle: String, Codable, CaseIterable, Identifiable {
    case natural, casual
    var id: String { rawValue }
    var label: String { self == .natural ? "Natural" : "Very casual" }
    /// Position in the proxy's two options (Natural first, Very casual second).
    var optionIndex: Int { self == .natural ? 0 : 1 }
}

enum Tone: String, Codable, CaseIterable, Identifiable {
    case warm, playful, neutral, firm
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

/// Simplified = mainland vocabulary, traditional = Taiwan vocabulary (for now).
enum ChineseScript: String, Codable, CaseIterable, Identifiable {
    case simplified, traditional
    var id: String { rawValue }
    var label: String { self == .simplified ? "简体" : "繁體" }
    var region: String { self == .simplified ? "mainland" : "taiwan" }
}

/// Language of the one-line reasons under corrections and rephrasings.
enum ExplainLanguage: String, Codable, CaseIterable, Identifiable {
    case english = "en"
    case korean = "ko"
    case chineseSimplified = "zh-Hans"
    case chineseTraditional = "zh-Hant"
    var id: String { rawValue }
    var label: String {
        switch self {
        case .english: return "English"
        case .korean: return "한국어"
        case .chineseSimplified: return "简体中文"
        case .chineseTraditional: return "繁體中文"
        }
    }
}

/// Model keys the proxy accepts. See docs/PROJECT.md, section 3.
enum CheckModel: String, Codable, CaseIterable, Identifiable {
    case haiku, haiku_think, sonnet, gemini_lite, gemini_flash
    var id: String { rawValue }
    var label: String {
        switch self {
        case .haiku: return "Haiku 5.5"
        case .haiku_think: return "Haiku 5.5 (thinking)"
        case .sonnet: return "Sonnet 5.5"
        case .gemini_lite: return "Gemini 3.5 Flash-Lite"
        case .gemini_flash: return "Gemini 3.8 Flash"
        }
    }
}

/// Who you're texting and how, set per language in the keyboard's settings panel.
struct CheckContext: Codable, Equatable {
    var speechLevel: SpeechLevel = .banmal
    /// Optional, free text: "friend", "선배", "my boss".
    var speakingTo: String = ""
    var listenerAge: RelativeAge = .same
    var listenerGender: Gender = .unset
    var tone: Tone = .neutral
    var rephraseStyle: RephraseStyle = .natural
    /// "What I mean", sent with every check until cleared.
    var note: String = ""

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = CheckContext()
        speechLevel = (try? c.decodeIfPresent(SpeechLevel.self, forKey: .speechLevel)) ?? d.speechLevel
        speakingTo = (try? c.decodeIfPresent(String.self, forKey: .speakingTo)) ?? d.speakingTo
        listenerAge = (try? c.decodeIfPresent(RelativeAge.self, forKey: .listenerAge)) ?? d.listenerAge
        listenerGender = (try? c.decodeIfPresent(Gender.self, forKey: .listenerGender)) ?? d.listenerGender
        tone = (try? c.decodeIfPresent(Tone.self, forKey: .tone)) ?? d.tone
        rephraseStyle = (try? c.decodeIfPresent(RephraseStyle.self, forKey: .rephraseStyle)) ?? d.rephraseStyle
        note = (try? c.decodeIfPresent(String.self, forKey: .note)) ?? d.note
    }
}

/// Everything the keyboard and the companion app share through the App Group.
struct KeyboardSettings: Codable, Equatable {
    var language: KeyboardLanguage = .korean
    var contexts: [KeyboardLanguage: CheckContext] = [:]
    var script: ChineseScript = .traditional
    var speakerGender: Gender = .unset
    var explainLanguage: ExplainLanguage = .english
    var model: CheckModel = .sonnet
    var checksEnabled: Bool = true
    /// Seconds without typing before a check starts.
    var pauseSeconds: Double = 1.0
    var recentEmoji: [String] = []

    init() {}

    // Decode field by field so settings saved by an older build survive new fields.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = KeyboardSettings()
        language = (try? c.decodeIfPresent(KeyboardLanguage.self, forKey: .language)) ?? d.language
        contexts = (try? c.decodeIfPresent([KeyboardLanguage: CheckContext].self, forKey: .contexts)) ?? d.contexts
        script = (try? c.decodeIfPresent(ChineseScript.self, forKey: .script)) ?? d.script
        speakerGender = (try? c.decodeIfPresent(Gender.self, forKey: .speakerGender)) ?? d.speakerGender
        explainLanguage = (try? c.decodeIfPresent(ExplainLanguage.self, forKey: .explainLanguage)) ?? d.explainLanguage
        model = (try? c.decodeIfPresent(CheckModel.self, forKey: .model)) ?? d.model
        checksEnabled = (try? c.decodeIfPresent(Bool.self, forKey: .checksEnabled)) ?? d.checksEnabled
        pauseSeconds = (try? c.decodeIfPresent(Double.self, forKey: .pauseSeconds)) ?? d.pauseSeconds
        recentEmoji = (try? c.decodeIfPresent([String].self, forKey: .recentEmoji)) ?? d.recentEmoji
    }

    func context(for language: KeyboardLanguage) -> CheckContext {
        contexts[language] ?? CheckContext()
    }

    mutating func updateContext(for language: KeyboardLanguage, _ change: (inout CheckContext) -> Void) {
        var ctx = context(for: language)
        change(&ctx)
        contexts[language] = ctx
    }

    mutating func addRecentEmoji(_ emoji: String) {
        recentEmoji.removeAll { $0 == emoji }
        recentEmoji.insert(emoji, at: 0)
        if recentEmoji.count > 32 { recentEmoji.removeLast(recentEmoji.count - 32) }
    }

    /// The `profile` object the proxy expects.
    func proxyProfile(for language: KeyboardLanguage) -> ProxyProfile {
        let ctx = context(for: language)
        let speakingTo = ctx.speakingTo.trimmingCharacters(in: .whitespacesAndNewlines)
        var out = ProxyProfile(relationship: speakingTo.isEmpty ? nil : speakingTo, tone: ctx.tone.rawValue)
        switch language {
        case .korean:
            out.speech_level = ctx.speechLevel.rawValue
            out.listener_age = ctx.listenerAge.rawValue
            out.listener_gender = ctx.listenerGender == .unset ? nil : ctx.listenerGender.rawValue
            out.speaker_gender = speakerGender == .unset ? nil : speakerGender.rawValue
        case .chinese:
            out.region = script.region
            out.script = script.rawValue
        }
        return out
    }
}
