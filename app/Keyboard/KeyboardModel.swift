import UIKit
import SwiftUI

/// Result of the pause check, shown in the card above the bar.
enum CheckState: Equatable {
    case idle
    case checking
    case ok(text: String)
    /// Correct but textbook-like: the card offers more natural versions.
    case stiff(text: String)
    case fix(original: String, corrected: String, tip: String)
    case rephrasing(original: String)
    /// The rewrite in the style chosen in settings (one at a time, to keep the card short).
    case rephrased(original: String, option: RephraseOption)
    case message(String)
    /// Checks need Full Access; the card links to the app, which opens Settings.
    case needsFullAccess
    /// The app has no token, or the proxy rejected it: link to the Checks tab.
    case needsSetup

    /// Something the card shows.
    var hasCard: Bool {
        switch self {
        case .idle, .checking, .ok: return false
        default: return true
        }
    }
}

enum KeyboardPanel: Equatable {
    case keys
    case settings
}

/// Text fields in the settings panel. The keyboard types into them itself,
/// because its keys can't reach a text field inside the keyboard.
enum SettingsField: Equatable {
    case speakingTo
    case note

    var title: String { self == .speakingTo ? "Speaking to" : "What I mean" }
    var placeholder: String { self == .speakingTo ? "Optional, e.g. 선배, my boss" : "Optional, e.g. teasing, not serious" }
}

/// One slot in the suggestion bar.
struct Suggestion: Identifiable, Equatable {
    enum Kind: Equatable {
        /// Replaces the word being typed (this many characters before the cursor).
        case completion(replacing: Int)
        /// Chinese candidate that uses up this many pinyin letters.
        case candidate(consumed: Int)
    }
    let text: String
    let kind: Kind
    var id: String { text + "\(kind)" }
}

@MainActor
final class KeyboardModel: ObservableObject {
    weak var controller: KeyboardViewController?

    @Published var settings: KeyboardSettings
    @Published var page: KeyboardPage = .letters
    @Published var panel: KeyboardPanel = .keys
    @Published var shift = false
    @Published var check: CheckState = .idle
    @Published var suggestions: [Suggestion] = []
    @Published var showGlobe = false
    @Published var isDark = true

    /// Settings being edited; saved to `settings` on Done.
    @Published var draft: KeyboardSettings?
    @Published var editingField: SettingsField?
    @Published var fieldText = ""
    /// ABC instead of Hangul while typing into a settings field.
    @Published var fieldLatin = false

    /// Pinyin typed but not yet turned into characters (shown as marked text).
    @Published private(set) var pinyin = ""

    /// Set by snapshot tests, which have no keyboard controller.
    var fullAccessOverride: Bool?

    private let store: SettingsStore
    private var composer = HangulComposer()
    /// Characters of the syllable being built that are already in the target text.
    private var composingLength = 0
    private var checkTask: Task<Void, Never>?
    /// What was sent to the last check, with the whitespace after it.
    private var checkedRaw = ""

    private var korean: KoreanLexicon?
    private var chinese: PinyinLexicon?
    private(set) var emoji: EmojiCatalog?

    init(store: SettingsStore = .shared) {
        self.store = store
        self.settings = store.load()
    }

    private var proxy: UITextDocumentProxy? { controller?.textDocumentProxy }
    var language: KeyboardLanguage { settings.language }
    /// Opens the companion app, which jumps straight to its Settings page
    /// (Keyboards › Allow Full Access). Keyboards can't open Settings directly.
    func openFullAccessSettings() {
        guard let url = URL(string: "languagekeyboard://full-access") else { return }
        controller?.openContainingApp(url)
    }

    /// Opens the app on its Checks tab, where the token is entered.
    func openCheckSetup() {
        guard let url = URL(string: "languagekeyboard://checks") else { return }
        controller?.openContainingApp(url)
    }

    static func state(for error: Error) -> CheckState {
        switch error as? ProxyError {
        case .missingToken, .http(401, _): return .needsSetup
        default: return .message(error.localizedDescription)
        }
    }

    var hasFullAccess: Bool { fullAccessOverride ?? controller?.hasFullAccess ?? false }

    /// Which letters to show right now.
    var letterLayout: LetterLayout {
        if editingField != nil { return (language == .korean && !fieldLatin) ? .hangul : .latin }
        return language == .korean ? .hangul : .latin
    }

    // MARK: - Lifecycle

    func reload() {
        settings = store.load()
        composer.reset()
        composingLength = 0
        pinyin = ""
        check = .idle
        page = .letters
        panel = .keys
        draft = nil
        editingField = nil
        loadResources()
        refreshSuggestions()
    }

    /// Word lists load off the main thread (the Korean list takes ~0.3s).
    func loadResources(synchronously: Bool = false) {
        let bundle = Bundle(for: KeyboardModel.self)
        let koURL = bundle.url(forResource: "ko_words", withExtension: "txt")
        let zhURL = bundle.url(forResource: "zh_pinyin", withExtension: "tsv")
        let emojiURL = bundle.url(forResource: "emoji", withExtension: "tsv")
        if emoji == nil, let emojiURL { emoji = EmojiCatalog(url: emojiURL) }
        if synchronously {
            if korean == nil, let koURL { korean = KoreanLexicon(url: koURL) }
            if chinese == nil, let zhURL { chinese = PinyinLexicon(url: zhURL) }
            return
        }
        if korean == nil, let koURL {
            Task.detached(priority: .userInitiated) {
                let lexicon = KoreanLexicon(url: koURL)
                await MainActor.run { [weak self] in
                    self?.korean = lexicon
                    self?.refreshSuggestions()
                }
            }
        }
        if chinese == nil, let zhURL {
            Task.detached(priority: .userInitiated) {
                let lexicon = PinyinLexicon(url: zhURL)
                await MainActor.run { [weak self] in self?.chinese = lexicon }
            }
        }
    }

    /// Called when the host app changes the text (sent message, moved cursor, pasted).
    func textDidChange() {
        guard editingField == nil else { return }
        let before = proxy?.documentContextBeforeInput ?? ""
        if composingLength > 0 && !before.hasSuffix(composer.composing) {
            composer.reset()
            composingLength = 0
        }
        if before.isEmpty && (proxy?.documentContextAfterInput ?? "").isEmpty {
            cancelCheck()
            check = .idle
        }
        refreshSuggestions()
    }

    // MARK: - Keys

    func tap(_ kind: KeyKind) {
        switch kind {
        case .text(let s, let shifted):
            guard !s.isEmpty else { return }
            type((shift ? shifted : nil) ?? s)
            if shift { shift = false }
        case .shift:
            shift.toggle()
        case .delete:
            deleteBackward()
        case .numbers:
            commitComposition()
            page = .numbers
        case .letters:
            page = .letters
        case .emoji:
            commitComposition()
            commitPinyin()
            page = .emoji
        case .fieldLayoutToggle:
            commitComposition()
            fieldLatin.toggle()
        case .space:
            if !pinyin.isEmpty {
                if let first = suggestions.first { choose(first) } else { commitPinyin() }
                return
            }
            commitComposition()
            insertRaw(" ")
            afterTyping(" ")
        case .returnKey:
            if editingField != nil { finishEditingField(); return }
            if !pinyin.isEmpty { commitPinyin(); refreshSuggestions(); return }
            commitComposition()
            proxy?.insertText("\n")
            cancelCheck()
            check = .idle
            refreshSuggestions()
        case .nextKeyboard:
            break // handled by the system button
        }
    }

    /// Long press on return applies whatever the card shows (a correction or a rewrite).
    var canQuickApply: Bool {
        guard editingField == nil else { return false }
        switch check {
        case .fix, .rephrased: return true
        default: return false
        }
    }

    func quickApply() {
        guard canQuickApply else { return }
        applyCard()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func typeEmoji(_ e: String) {
        commitComposition()
        commitPinyin()
        insertRaw(e)
        settings.addRecentEmoji(e)
        if hasFullAccess { store.save(settings) }
        afterTyping(nil)
    }

    private func type(_ s: String) {
        let isLetter = s.count == 1 && s.first!.isLetter
        if letterLayout == .hangul, page == .letters, s.count == 1, let c = s.first, HangulComposer.isJamo(c) {
            apply(composer.input(c))
        } else if editingField == nil, language == .chinese, page == .letters, isLetter, s.first!.isASCII {
            pinyin += s.lowercased()
            updateMarkedPinyin()
            refreshSuggestions()
            return
        } else {
            commitComposition()
            if !pinyin.isEmpty, let first = suggestions.first { choose(first) }
            insertRaw(s)
        }
        afterTyping(s)
    }

    private func deleteBackward() {
        if !pinyin.isEmpty {
            pinyin.removeLast()
            updateMarkedPinyin()
            refreshSuggestions()
            return
        }
        if let out = composer.backspace() {
            apply(out)
        } else {
            deleteRaw()
        }
        afterTyping(nil)
    }

    /// Replace the syllable in progress with the composer's output.
    private func apply(_ out: HangulComposer.Output) {
        for _ in 0..<composingLength { deleteRaw() }
        let text = out.committed + out.composing
        if !text.isEmpty { insertRaw(text) }
        composingLength = out.composing.count
    }

    private func commitComposition() {
        _ = composer.commit() // already in the text
        composingLength = 0
    }

    private func insertRaw(_ s: String) {
        if editingField != nil { fieldText += s } else { proxy?.insertText(s) }
    }

    private func deleteRaw() {
        if editingField != nil {
            if !fieldText.isEmpty { fieldText.removeLast() }
        } else {
            proxy?.deleteBackward()
        }
    }

    // MARK: - Pinyin

    private func updateMarkedPinyin() {
        guard let proxy else { return }
        proxy.setMarkedText(pinyin, selectedRange: NSRange(location: (pinyin as NSString).length, length: 0))
        if pinyin.isEmpty { proxy.unmarkText() }
    }

    /// Commit the letters as typed (return key, or switching away).
    private func commitPinyin() {
        guard !pinyin.isEmpty else { return }
        proxy?.unmarkText()
        pinyin = ""
    }

    /// Test hook: type pinyin without a text document.
    func setPinyinForPreview(_ text: String) {
        pinyin = text
        refreshSuggestions()
    }

    // MARK: - Suggestions

    private func refreshSuggestions() {
        guard editingField == nil else { suggestions = []; return }
        if language == .chinese {
            guard let chinese, !pinyin.isEmpty else { suggestions = []; return }
            suggestions = chinese.candidates(for: pinyin, script: settings.script, limit: 20)
                .map { Suggestion(text: $0.text, kind: .candidate(consumed: $0.consumed)) }
            return
        }
        guard let korean else { suggestions = []; return }
        let word = currentWord()
        suggestions = korean.completions(for: word, limit: 3)
            .map { Suggestion(text: $0, kind: .completion(replacing: word.count)) }
    }

    /// Test hook: show suggestions for a word without a text document.
    func setWordForPreview(_ word: String) {
        suggestions = (korean?.completions(for: word, limit: 3) ?? [])
            .map { Suggestion(text: $0, kind: .completion(replacing: word.count)) }
    }

    /// Hangul at the end of the text before the cursor.
    private func currentWord() -> String {
        let before = proxy?.documentContextBeforeInput ?? ""
        var word = ""
        for c in before.reversed() {
            guard c.unicodeScalars.allSatisfy({ (0xAC00...0xD7A3).contains($0.value) || (0x3131...0x318E).contains($0.value) }) else { break }
            word.insert(c, at: word.startIndex)
        }
        return word
    }

    func choose(_ suggestion: Suggestion) {
        switch suggestion.kind {
        case .candidate(let consumed):
            guard let proxy else { return }
            proxy.setMarkedText(suggestion.text, selectedRange: NSRange(location: (suggestion.text as NSString).length, length: 0))
            proxy.unmarkText()
            pinyin = String(pinyin.dropFirst(consumed))
            if !pinyin.isEmpty { updateMarkedPinyin() }
            refreshSuggestions()
            if pinyin.isEmpty { afterTyping(nil) }
        case .completion(let replacing):
            commitComposition()
            for _ in 0..<replacing { proxy?.deleteBackward() }
            proxy?.insertText(suggestion.text + " ")
            afterTyping(" ")
        }
    }

    // MARK: - Pause check

    private func afterTyping(_ s: String?) {
        guard editingField == nil else { return }
        refreshSuggestions()
        cancelCheck()
        if check != .idle { check = .idle }
        guard settings.checksEnabled else { return }
        let endsSentence = s.map { ".?!。？！".contains($0) } ?? false
        let delay = endsSentence ? 0 : settings.pauseSeconds
        checkTask = Task { [weak self] in
            if delay > 0 { try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
            guard !Task.isCancelled else { return }
            await self?.runCheck()
        }
    }

    private func cancelCheck() {
        checkTask?.cancel()
        checkTask = nil
    }

    /// Text before the cursor, split into (what to check, the same with the whitespace after it).
    private func currentText() -> (text: String, raw: String)? {
        let before = String((proxy?.documentContextBeforeInput ?? "").suffix(1000))
        let trimmed = before.trimmingCharacters(in: .whitespacesAndNewlines)
        let letters = trimmed.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
        guard letters >= 2 else { return nil }
        guard let range = before.range(of: trimmed, options: .backwards) else { return nil }
        return (trimmed, String(before[range.lowerBound...]))
    }

    private func runCheck() async {
        // Never check half a syllable (lone ㄱ or ㅏ) or unconverted pinyin.
        guard !composer.isIncomplete, pinyin.isEmpty, let current = currentText() else { return }
        guard hasFullAccess else {
            check = .needsFullAccess
            return
        }
        checkedRaw = current.raw
        check = .checking
        do {
            let (response, _) = try await ProxyClient.shared.check(request(for: current.text))
            guard !Task.isCancelled, currentText()?.raw == current.raw else { return }
            if response.isFix, let corrected = response.corrected {
                check = .fix(original: current.text, corrected: corrected, tip: response.tip ?? "")
            } else if response.stiff == true {
                check = .stiff(text: current.text)
            } else {
                check = .ok(text: current.text)
            }
        } catch {
            guard !Task.isCancelled, !(error is CancellationError) else { return }
            if (error as? URLError)?.code == .cancelled { return }
            check = Self.state(for: error)
        }
    }

    private func request(for text: String) -> CheckRequest {
        let note = settings.context(for: language).note.trimmingCharacters(in: .whitespacesAndNewlines)
        return CheckRequest(
            lang: language.rawValue,
            text: text,
            context: nil,
            profile: settings.proxyProfile(for: language),
            note: note.isEmpty ? nil : note,
            model: settings.model.rawValue,
            explain: settings.explainLanguage.rawValue
        )
    }

    // MARK: - Results

    /// The card's blue arrow, or a long press on return.
    func applyCard() {
        switch check {
        case .fix(let original, let corrected, _): replace(original: original, with: corrected)
        case .rephrased(let original, let option): replace(original: original, with: option.text)
        default: break
        }
    }

    func rephrase() {
        guard case .stiff(let text) = check else { return }
        check = .rephrasing(original: text)
        checkTask = Task { [weak self] in
            guard let self else { return }
            do {
                let response = try await ProxyClient.shared.rephrase(self.request(for: text))
                guard !Task.isCancelled else { return }
                let style = self.settings.context(for: self.language).rephraseStyle
                let options = response.options
                if options.isEmpty {
                    self.check = .ok(text: text)
                } else {
                    let option = options.indices.contains(style.optionIndex) ? options[style.optionIndex] : options[0]
                    self.check = .rephrased(original: text, option: option)
                }
            } catch {
                guard !Task.isCancelled else { return }
                self.check = Self.state(for: error)
            }
        }
    }

    func dismissResult() {
        cancelCheck()
        check = .idle
    }

    /// Swap the checked text for a new version, only if it's still what's before the cursor.
    private func replace(original: String, with new: String) {
        guard let current = currentText(), current.text == original, current.raw == checkedRaw else {
            check = .message("The text changed, so this wasn't applied")
            return
        }
        commitComposition()
        let trailing = String(current.raw.dropFirst(original.count))
        for _ in 0..<current.raw.count { proxy?.deleteBackward() }
        proxy?.insertText(new + trailing)
        cancelCheck()
        check = .ok(text: new)
        refreshSuggestions()
    }

    // MARK: - Settings

    func openSettings() {
        commitComposition()
        commitPinyin()
        draft = settings
        panel = .settings
    }

    /// Done: keep the changes.
    func saveSettings() {
        guard let draft else { panel = .keys; return }
        let languageChanged = draft.language != settings.language
        settings = draft
        self.draft = nil
        panel = .keys
        page = .letters
        shift = false
        if languageChanged { check = .idle; suggestions = [] }
        if hasFullAccess { store.save(settings) }
        refreshSuggestions()
    }

    func beginEditing(_ field: SettingsField) {
        guard let draft else { return }
        let ctx = draft.context(for: draft.language)
        fieldText = field == .speakingTo ? ctx.speakingTo : ctx.note
        fieldLatin = false
        composer.reset()
        composingLength = 0
        editingField = field
        page = .letters
        panel = .keys
    }

    func finishEditingField() {
        commitComposition()
        guard let field = editingField, draft != nil else { editingField = nil; return }
        let text = fieldText.trimmingCharacters(in: .whitespacesAndNewlines)
        let lang = draft!.language
        draft!.updateContext(for: lang) {
            if field == .speakingTo { $0.speakingTo = text } else { $0.note = text }
        }
        editingField = nil
        panel = .settings
    }

    /// Settings panel bindings write to the draft. (SwiftUI calls these on the main thread.)
    func draftBinding<T: Sendable>(_ keyPath: WritableKeyPath<KeyboardSettings, T>, default value: T) -> Binding<T> {
        Binding(get: {
            MainActor.assumeIsolated { self.draft?[keyPath: keyPath] ?? value }
        }, set: { newValue in
            MainActor.assumeIsolated { self.draft?[keyPath: keyPath] = newValue }
        })
    }

    func contextBinding<T: Sendable>(_ keyPath: WritableKeyPath<CheckContext, T>) -> Binding<T> {
        Binding(get: {
            MainActor.assumeIsolated {
                let s = self.draft ?? self.settings
                return s.context(for: s.language)[keyPath: keyPath]
            }
        }, set: { newValue in
            MainActor.assumeIsolated {
                guard let lang = self.draft?.language else { return }
                self.draft?.updateContext(for: lang) { $0[keyPath: keyPath] = newValue }
            }
        })
    }

    // MARK: - Labels

    var returnLabel: String {
        switch proxy?.returnKeyType ?? .default {
        case .send: return "Send"
        case .search, .google, .yahoo: return "Search"
        case .go: return "Go"
        case .done: return "Done"
        case .next: return "Next"
        default: return ""
        }
    }
}
