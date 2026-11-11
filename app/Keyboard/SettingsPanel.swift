import SwiftUI

/// "Check settings", opened from the settings icon. Takes the place of the
/// bar and keys at the same height for every language. Changes are a draft
/// until Done.
struct SettingsPanel: View {
    @ObservedObject var model: KeyboardModel
    let theme: KeyboardTheme

    private var draft: KeyboardSettings { model.draft ?? model.settings }
    private var language: KeyboardLanguage { draft.language }
    private var context: CheckContext { draft.context(for: language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            // Done sits on the first row so every setting fits in the keyboard's height.
            row("Language") {
                HStack(spacing: 10) {
                    Picker("Language", selection: model.draftBinding(\.language, default: model.language)) {
                        ForEach(KeyboardLanguage.allCases) { Text($0.name).tag($0) }
                    }
                    Button { model.saveSettings() } label: {
                        Text("Done")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .frame(height: 32)
                            .background(Capsule().fill(theme.accent))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Saves these settings")
                }
            }

            if language == .korean {
                row("Speech level") {
                    Picker("Speech level", selection: model.contextBinding(\.speechLevel)) {
                        ForEach(SpeechLevel.allCases) { Text($0.label).tag($0) }
                    }
                }
                row("Speaking to") { field(.speakingTo, value: context.speakingTo) }
                row("They are") {
                    HStack(spacing: 8) {
                        Picker("Age", selection: model.contextBinding(\.listenerAge)) {
                            ForEach(RelativeAge.allCases) { Text($0.label).tag($0) }
                        }
                        Picker("Gender", selection: model.contextBinding(\.listenerGender)) {
                            ForEach(Gender.allCases) { g in
                                Text(g.short).tag(g).accessibilityLabel(g.label)
                            }
                        }
                        .frame(width: 84)
                    }
                }
            } else {
                row("Script") {
                    Picker("Script", selection: model.draftBinding(\.script, default: model.settings.script)) {
                        ForEach(ChineseScript.allCases) { Text($0.label).tag($0) }
                    }
                }
                row("Speaking to") { field(.speakingTo, value: context.speakingTo) }
            }

            row("Tone") {
                Picker("Tone", selection: model.contextBinding(\.tone)) {
                    ForEach(Tone.allCases) { Text($0.label).tag($0) }
                }
            }
            row("Rewrite as") {
                Picker("Rewrite as", selection: model.contextBinding(\.rephraseStyle)) {
                    ForEach(RephraseStyle.allCases) { Text($0.label).tag($0) }
                }
            }
            row("What I mean") { field(.note, value: context.note) }

            Spacer(minLength: 0)

            if !model.hasFullAccess {
                Text("Full Access is off: checks are paused and settings can't be saved.")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.warning)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    private func row<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(width: 78, alignment: .leading)
            content()
                .frame(maxWidth: .infinity)
        }
        .frame(height: 32)
    }

    /// Looks like a text field; tapping it types into it with the keyboard's own keys.
    private func field(_ field: SettingsField, value: String) -> some View {
        Button { model.beginEditing(field) } label: {
            HStack {
                Text(value.isEmpty ? field.placeholder : value)
                    .font(.system(size: 14))
                    .foregroundStyle(value.isEmpty ? theme.tertiaryText : theme.text)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if !value.isEmpty {
                    Image(systemName: "pencil")
                        .font(.system(size: 13))
                        .foregroundStyle(theme.tertiaryText)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(theme.segmentTrack))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(field.title)
        .accessibilityValue(value.isEmpty ? "Empty" : value)
    }
}
