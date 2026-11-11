import SwiftUI

struct ProfilesView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.scenePhase) private var scenePhase
    @State private var language: KeyboardLanguage = .korean

    var body: some View {
        NavigationStack {
            Form {
                Picker("Language", selection: $language) {
                    ForEach(KeyboardLanguage.allCases) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)

                Section("Who you're texting") {
                    let active = settings.value.activeProfile(for: language)
                    ForEach(settings.value.profiles(for: language)) { profile in
                        NavigationLink {
                            ProfileEditor(language: language, profileID: profile.id)
                        } label: {
                            HStack {
                                Text(profile.name)
                                Spacer()
                                if profile.id == active.id {
                                    Text("In use").foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete { offsets in
                        var list = settings.value.profiles(for: language)
                        guard list.count - offsets.count >= 1 else { return }
                        list.remove(atOffsets: offsets)
                        settings.value.profiles[language] = list
                    }
                    Button {
                        var list = settings.value.profiles(for: language)
                        let profile = Profile(name: "New", relationship: "friend")
                        list.append(profile)
                        settings.value.profiles[language] = list
                    } label: {
                        Label("Add profile", systemImage: "plus")
                    }
                }

                Section("About you") {
                    Picker("Your gender", selection: $settings.value.speakerGender) {
                        Text("Male").tag(Gender.male)
                        Text("Female").tag(Gender.female)
                    }
                }

                if language == .chinese {
                    Section("Chinese") {
                        Picker("Region", selection: $settings.value.region) {
                            ForEach(ChineseRegion.allCases) { Text($0.label).tag($0) }
                        }
                        Picker("Script", selection: $settings.value.script) {
                            ForEach(ChineseScript.allCases) { Text($0.label).tag($0) }
                        }
                    }
                }

                Section {
                    TextField("e.g. teasing, not serious", text: $settings.value.note)
                } header: {
                    Text("What I mean")
                } footer: {
                    Text("Sent with every check until you clear it.")
                }
            }
            .navigationTitle("Profiles")
            .onAppear { language = settings.value.language }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { settings.reload() }
            }
        }
    }
}

struct ProfileEditor: View {
    @EnvironmentObject private var settings: AppSettings
    let language: KeyboardLanguage
    let profileID: UUID

    private var binding: Binding<Profile> {
        Binding {
            settings.value.profiles(for: language).first { $0.id == profileID }
                ?? Profile(name: "", relationship: "")
        } set: { updated in
            var list = settings.value.profiles(for: language)
            if let index = list.firstIndex(where: { $0.id == profileID }) {
                list[index] = updated
                settings.value.profiles[language] = list
            }
        }
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: binding.name)
                TextField("Relationship (sent to the check)", text: binding.relationship)
                Picker("Tone", selection: binding.tone) {
                    ForEach(Tone.allCases) { Text($0.label).tag($0) }
                }
            }
            if language == .korean {
                Section("Korean") {
                    Picker("Speech level", selection: binding.speechLevel) {
                        ForEach(SpeechLevel.allCases) { Text($0.label).tag($0) }
                    }
                    Picker("They are", selection: binding.listenerAge) {
                        ForEach(RelativeAge.allCases) { Text($0.label).tag($0) }
                    }
                    Picker("Their gender", selection: binding.listenerGender) {
                        Text("Not set").tag(Gender?.none)
                        Text("Male").tag(Gender?.some(.male))
                        Text("Female").tag(Gender?.some(.female))
                    }
                }
            }
            Section {
                Button("Use this profile") {
                    settings.value.activeProfileID[language] = profileID
                }
            }
        }
        .navigationTitle(binding.wrappedValue.name.isEmpty ? "Profile" : binding.wrappedValue.name)
    }
}
