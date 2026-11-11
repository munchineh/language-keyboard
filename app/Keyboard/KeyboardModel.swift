import UIKit
import SwiftUI

/// What the suggestion bar (and the card above it) shows.
enum BarState: Equatable {
    case idle
    case checking
    /// Nothing to fix. `stiff`: correct but could sound more natural.
    case ok(stiff: Bool, text: String)
    case fix(original: String, corrected: String, tip: String)
    case rephrasing(original: String)
    case options(original: String, options: [RephraseOption])
    case message(String)
}

enum KeyboardPanel: Equatable {
    case keys
    case settings
}

@MainActor
final class KeyboardModel: ObservableObject {
    weak var controller: KeyboardViewController?

    @Published var settings: KeyboardSettings
    @Published var page: KeyboardPage = .letters
    @Published var panel: KeyboardPanel = .keys
    @Published var shift = false
    @Published var bar: BarState = .idle
    @Published var showGlobe = false
    @Published var isDark = true

    private let store: SettingsStore
    private var composer = HangulComposer()
    /// Characters of the syllable being built that are already in the document.
    private var composingLength = 0
    private var checkTask: Task<Void, Never>?
    /// What was sent to the last check, with the whitespace after it.
    private var checkedRaw = ""

    init(store: SettingsStore = .shared) {
        self.store = store
        self.settings = store.load()
    }

    private var proxy: UITextDocumentProxy? { controller?.textDocumentProxy }
    var language: KeyboardLanguage { settings.language }
    var hasFullAccess: Bool { controller?.hasFullAccess ?? false }

    // MARK: - Lifecycle

    func reload() {
        settings = store.load()
        composer.reset()
        composingLength = 0
        bar = .idle
        page = .letters
        panel = .keys
    }

    /// Called when the host app changes the text (sent message, moved cursor, pasted).
    func textDidChange() {
        let before = proxy?.documentContextBeforeInput ?? ""
        if composingLength > 0 && !before.hasSuffix(composer.composing) {
            composer.reset()
            composingLength = 0
        }
        if before.isEmpty && (proxy?.documentContextAfterInput ?? "").isEmpty {
            cancelCheck()
            bar = .idle
        }
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
        case .languageToggle:
            commitComposition()
            let all = KeyboardLanguage.allCases
            let next = all[(all.firstIndex(of: language)! + 1) % all.count]
            setLanguage(next)
        case .space:
            commitComposition()
            proxy?.insertText(" ")
            afterTyping(" ")
        case .returnKey:
            commitComposition()
            proxy?.insertText("\n")
            cancelCheck()
            bar = .idle
        case .nextKeyboard:
            break // handled by the system button
        }
    }

    private func type(_ s: String) {
        if language == .korean, page == .letters, s.count == 1, let c = s.first, HangulComposer.isJamo(c) {
            apply(composer.input(c))
        } else {
            commitComposition()
            proxy?.insertText(s)
        }
        afterTyping(s)
    }

    private func deleteBackward() {
        if let out = composer.backspace() {
            apply(out)
        } else {
            proxy?.deleteBackward()
        }
        afterTyping(nil)
    }

    /// Replace the syllable in progress with the composer's output.
    private func apply(_ out: HangulComposer.Output) {
        for _ in 0..<composingLength { proxy?.deleteBackward() }
        let text = out.committed + out.composing
        if !text.isEmpty { proxy?.insertText(text) }
        composingLength = out.composing.count
    }

    private func commitComposition() {
        _ = composer.commit() // already in the document
        composingLength = 0
    }

    // MARK: - Pause check

    private func afterTyping(_ s: String?) {
        cancelCheck()
        if bar != .idle { bar = .idle }
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

    /// Text before the cursor, split into (what to check, whitespace after it).
    private func currentText() -> (text: String, raw: String)? {
        let before = String((proxy?.documentContextBeforeInput ?? "").suffix(1000))
        let trimmed = before.trimmingCharacters(in: .whitespacesAndNewlines)
        let letters = trimmed.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
        guard letters >= 2 else { return nil }
        // Keep only the part from where the trimmed text starts, so Apply can replace it exactly.
        guard let range = before.range(of: trimmed, options: .backwards) else { return nil }
        return (trimmed, String(before[range.lowerBound...]))
    }

    private func runCheck() async {
        // Never check half a syllable (lone ㄱ or ㅏ at the end).
        guard !composer.isIncomplete, let current = currentText() else { return }
        guard hasFullAccess else {
            bar = .message("Turn on Full Access to check")
            return
        }
        checkedRaw = current.raw
        bar = .checking
        do {
            let (response, _) = try await ProxyClient.shared.check(request(for: current.text))
            guard !Task.isCancelled, currentText()?.raw == current.raw else { return }
            if response.isFix, let corrected = response.corrected {
                bar = .fix(original: current.text, corrected: corrected, tip: response.tip ?? "")
            } else {
                bar = .ok(stiff: response.stiff ?? false, text: current.text)
            }
        } catch {
            guard !Task.isCancelled, !(error is CancellationError) else { return }
            if (error as? URLError)?.code == .cancelled { return }
            bar = .message(error.localizedDescription)
        }
    }

    private func request(for text: String) -> CheckRequest {
        let note = settings.note.trimmingCharacters(in: .whitespacesAndNewlines)
        return CheckRequest(
            lang: language.rawValue,
            text: text,
            context: nil,
            profile: settings.proxyProfile(for: language),
            note: note.isEmpty ? nil : note,
            model: settings.model.rawValue
        )
    }

    // MARK: - Results

    func applyCorrection() {
        guard case .fix(let original, let corrected, _) = bar else { return }
        replace(original: original, with: corrected)
    }

    func rephrase() {
        guard case .ok(_, let text) = bar else { return }
        bar = .rephrasing(original: text)
        checkTask = Task { [weak self] in
            guard let self else { return }
            do {
                let response = try await ProxyClient.shared.rephrase(self.request(for: text))
                guard !Task.isCancelled else { return }
                self.bar = response.options.isEmpty ? .ok(stiff: false, text: text) : .options(original: text, options: response.options)
            } catch {
                guard !Task.isCancelled else { return }
                self.bar = .message(error.localizedDescription)
            }
        }
    }

    func choose(_ option: RephraseOption) {
        guard case .options(let original, _) = bar else { return }
        replace(original: original, with: option.text)
    }

    func dismissResult() {
        cancelCheck()
        bar = .idle
    }

    /// Swap the checked text for a new version, only if it's still what's before the cursor.
    private func replace(original: String, with new: String) {
        guard let current = currentText(), current.text == original, current.raw == checkedRaw else {
            bar = .message("Text changed, check again")
            return
        }
        commitComposition()
        let trailing = String(current.raw.dropFirst(original.count))
        for _ in 0..<current.raw.count { proxy?.deleteBackward() }
        proxy?.insertText(new + trailing)
        cancelCheck()
        bar = .ok(stiff: false, text: new)
    }

    // MARK: - Settings

    func setLanguage(_ language: KeyboardLanguage) {
        commitComposition()
        settings.language = language
        page = .letters
        shift = false
        bar = .idle
        save()
    }

    func selectProfile(_ profile: Profile) {
        settings.activeProfileID[language] = profile.id
        save()
    }

    func updateProfile(_ change: (inout Profile) -> Void) {
        settings.updateActiveProfile(for: language, change)
        save()
    }

    func update(_ change: (inout KeyboardSettings) -> Void) {
        change(&settings)
        save()
    }

    private func save() {
        // Without Full Access the App Group is read-only; changes last until the keyboard closes.
        if hasFullAccess { store.save(settings) }
    }

    // MARK: - Labels

    var summary: String { settings.summary(for: language) }

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
