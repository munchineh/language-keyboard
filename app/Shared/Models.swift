import Foundation

/// Languages the keyboard can type and check. Matches the proxy's `lang` values.
enum KeyboardLanguage: String, Codable, CaseIterable, Identifiable, CodingKeyRepresentable {
    case korean = "ko"
    case chinese = "zh"

    var id: String { rawValue }
    /// Long label (settings, space bar).
    var name: String {
        switch self {
        case .korean: return "한국어"
        case .chinese: return "中文"
        }
    }
    /// One-character badge on the settings button.
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

enum Gender: String, Codable, CaseIterable, Identifiable {
    case male, female
    var id: String { rawValue }
    var short: String { self == .male ? "M" : "F" }
}

enum Tone: String, Codable, CaseIterable, Identifiable {
    case warm, playful, neutral, firm
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

enum ChineseRegion: String, Codable, CaseIterable, Identifiable {
    case mainland, taiwan
    var id: String { rawValue }
    var label: String { self == .mainland ? "Mainland" : "Taiwan" }
}

enum ChineseScript: String, Codable, CaseIterable, Identifiable {
    case simplified, traditional
    var id: String { rawValue }
    var label: String { self == .simplified ? "简体" : "繁體" }
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

/// Who you're texting. Saved per language ("Friend", "Senior", "Teacher", ...).
struct Profile: Codable, Identifiable, Equatable, Hashable {
    var id: UUID = UUID()
    var name: String
    var relationship: String
    var tone: Tone = .neutral
    // Korean
    var speechLevel: SpeechLevel = .banmal
    var listenerAge: RelativeAge = .same
    var listenerGender: Gender? = nil

    static func defaults(for language: KeyboardLanguage) -> [Profile] {
        switch language {
        case .korean:
            return [
                Profile(name: "Friend", relationship: "friend", tone: .playful, speechLevel: .banmal, listenerAge: .same),
                Profile(name: "Senior", relationship: "senior (선배)", tone: .warm, speechLevel: .haeyo, listenerAge: .older),
                Profile(name: "Teacher", relationship: "teacher", tone: .neutral, speechLevel: .haeyo, listenerAge: .older),
                Profile(name: "Stranger", relationship: "stranger", tone: .neutral, speechLevel: .haeyo, listenerAge: .same),
            ]
        case .chinese:
            return [
                Profile(name: "Friend", relationship: "friend", tone: .playful),
                Profile(name: "Colleague", relationship: "colleague", tone: .neutral),
                Profile(name: "Teacher", relationship: "teacher", tone: .neutral),
            ]
        }
    }
}

/// Everything the keyboard and the companion app share through the App Group.
struct KeyboardSettings: Codable, Equatable {
    var language: KeyboardLanguage = .korean
    var profiles: [KeyboardLanguage: [Profile]] = [
        .korean: Profile.defaults(for: .korean),
        .chinese: Profile.defaults(for: .chinese),
    ]
    var activeProfileID: [KeyboardLanguage: UUID] = [:]
    var speakerGender: Gender = .male
    var region: ChineseRegion = .taiwan
    var script: ChineseScript = .traditional
    var note: String = ""
    var model: CheckModel = .sonnet
    var checksEnabled: Bool = true
    /// Seconds without typing before a check starts.
    var pauseSeconds: Double = 1.0

    init() {}

    // Decode field by field so settings saved by an older build survive new fields.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = KeyboardSettings()
        language = (try? c.decodeIfPresent(KeyboardLanguage.self, forKey: .language)) ?? d.language
        profiles = (try? c.decodeIfPresent([KeyboardLanguage: [Profile]].self, forKey: .profiles)) ?? d.profiles
        activeProfileID = (try? c.decodeIfPresent([KeyboardLanguage: UUID].self, forKey: .activeProfileID)) ?? d.activeProfileID
        speakerGender = (try? c.decodeIfPresent(Gender.self, forKey: .speakerGender)) ?? d.speakerGender
        region = (try? c.decodeIfPresent(ChineseRegion.self, forKey: .region)) ?? d.region
        script = (try? c.decodeIfPresent(ChineseScript.self, forKey: .script)) ?? d.script
        note = (try? c.decodeIfPresent(String.self, forKey: .note)) ?? d.note
        model = (try? c.decodeIfPresent(CheckModel.self, forKey: .model)) ?? d.model
        checksEnabled = (try? c.decodeIfPresent(Bool.self, forKey: .checksEnabled)) ?? d.checksEnabled
        pauseSeconds = (try? c.decodeIfPresent(Double.self, forKey: .pauseSeconds)) ?? d.pauseSeconds
    }

    func profiles(for language: KeyboardLanguage) -> [Profile] {
        profiles[language] ?? Profile.defaults(for: language)
    }

    func activeProfile(for language: KeyboardLanguage) -> Profile {
        let list = profiles(for: language)
        if let id = activeProfileID[language], let match = list.first(where: { $0.id == id }) {
            return match
        }
        return list.first ?? Profile(name: "Friend", relationship: "friend")
    }

    mutating func updateActiveProfile(for language: KeyboardLanguage, _ change: (inout Profile) -> Void) {
        var list = profiles(for: language)
        let current = activeProfile(for: language)
        guard let index = list.firstIndex(where: { $0.id == current.id }) else { return }
        change(&list[index])
        profiles[language] = list
        activeProfileID[language] = list[index].id
    }

    /// Short summary for the suggestion bar, e.g. "Friend · 반말".
    func summary(for language: KeyboardLanguage) -> String {
        let p = activeProfile(for: language)
        switch language {
        case .korean: return "\(p.name) · \(p.speechLevel.label)"
        case .chinese: return "\(p.name) · \(region.label)"
        }
    }

    /// The `profile` object the proxy expects.
    func proxyProfile(for language: KeyboardLanguage) -> ProxyProfile {
        let p = activeProfile(for: language)
        var out = ProxyProfile(relationship: p.relationship, tone: p.tone.rawValue)
        switch language {
        case .korean:
            out.speech_level = p.speechLevel.rawValue
            out.listener_age = p.listenerAge.rawValue
            out.listener_gender = p.listenerGender?.rawValue
            out.speaker_gender = speakerGender.rawValue
        case .chinese:
            out.region = region.rawValue
            out.script = script.rawValue
        }
        return out
    }
}
