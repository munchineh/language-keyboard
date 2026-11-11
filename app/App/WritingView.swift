import SwiftUI

/// The same check settings as the keyboard's panel, with room for longer text,
/// plus settings that apply to every language.
struct WritingView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.scenePhase) private var scenePhase
    @State private var language: KeyboardLanguage = .korean

    private func binding<T>(_ keyPath: WritableKeyPath<CheckContext, T>) -> Binding<T> {
        Binding {
            settings.value.context(for: language)[keyPath: keyPath]
        } set: { newValue in
            settings.value.updateContext(for: language) { $0[keyPath: keyPath] = newValue }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Keyboard language", selection: $settings.value.language) {
                        ForEach(KeyboardLanguage.allCases) { Text($0.name).tag($0) }
                    }
                    Picker("Explain corrections in", selection: $settings.value.explainLanguage) {
                        ForEach(ExplainLanguage.allCases) { Text($0.label).tag($0) }
                    }
                    Picker("Your gender", selection: $settings.value.speakerGender) {
                        ForEach(Gender.allCases) { Text($0.label).tag($0) }
                    }
                } footer: {
                    Text("Your gender helps with words like 오빠 and 형.")
                }

                Picker("Settings for", selection: $language) {
                    ForEach(KeyboardLanguage.allCases) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)

                Section {
                    if language == .korean {
                        Picker("Speech level", selection: binding(\.speechLevel)) {
                            ForEach(SpeechLevel.allCases) { Text($0.label).tag($0) }
                        }
                    } else {
                        Picker("Script", selection: $settings.value.script) {
                            ForEach(ChineseScript.allCases) { Text($0.label).tag($0) }
                        }
                    }
                    TextField("Speaking to (optional)", text: binding(\.speakingTo))
                    if language == .korean {
                        Picker("They are", selection: binding(\.listenerAge)) {
                            ForEach(RelativeAge.allCases) { Text($0.label).tag($0) }
                        }
                        Picker("Their gender", selection: binding(\.listenerGender)) {
                            ForEach(Gender.allCases) { Text($0.label).tag($0) }
                        }
                    }
                    Picker("Tone", selection: binding(\.tone)) {
                        ForEach(Tone.allCases) { Text($0.label).tag($0) }
                    }
                    TextField("What I mean (optional)", text: binding(\.note))
                } header: {
                    Text(language.name)
                } footer: {
                    Text(language == .korean
                         ? "Also in the keyboard: tap the settings icon left of the suggestions."
                         : "简体 uses mainland words, 繁體 uses Taiwan words, for checks and suggestions.")
                }
            }
            .navigationTitle("Writing")
            .onAppear { language = settings.value.language }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { settings.reload() }
            }
        }
    }
}
