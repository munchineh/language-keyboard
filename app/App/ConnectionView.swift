import SwiftUI

struct ConnectionView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var result = ""
    @State private var testing = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: $settings.value.checksEnabled.animation()) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Check while typing")
                            Text(settings.value.checksEnabled
                                 ? "Checks your sentence when you stop typing."
                                 : "Off: nothing is checked and nothing leaves your phone. Word suggestions still work.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if settings.value.checksEnabled {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Pause before checking")
                                Spacer()
                                Text("\(settings.value.pauseSeconds, specifier: "%.1f")s")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            Text("How long you stop typing before a check starts. Shorter feels quicker; longer interrupts you less mid-sentence.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Slider(value: $settings.value.pauseSeconds, in: 0.6...2.0, step: 0.1)
                        }
                    }
                    Picker("Model", selection: $settings.value.model) {
                        ForEach(CheckModel.allCases) { Text($0.label).tag($0) }
                    }
                } header: {
                    Text("Checks")
                } footer: {
                    if settings.value.checksEnabled {
                        Text("Ending a sentence with . ? or ! checks straight away.")
                    }
                }

                Section {
                    TextField("Proxy URL", text: $settings.proxyURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    SecureField("App token", text: $settings.proxyToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Proxy")
                } footer: {
                    Text("Paste the token you saved when you set up the proxy.")
                }

                Section {
                    Button {
                        Task { await runTest() }
                    } label: {
                        HStack {
                            Text("Test a check")
                            if testing { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(testing)
                    if !result.isEmpty {
                        Text(result)
                            .font(.footnote.monospaced())
                            .textSelection(.enabled)
                    }
                } footer: {
                    Text("Sends 선생님한테 줬어 as a friend in 반말. Expect a fix to 선생님께 드렸어.")
                }
            }
            .navigationTitle("Checks")
        }
    }

    private func runTest() async {
        testing = true
        defer { testing = false }
        var profile = ProxyProfile()
        profile.relationship = "friend"
        profile.speech_level = "banmal"
        let request = CheckRequest(lang: "ko", text: "응, 어제 선생님한테 책을 줬어.", context: nil,
                                   profile: profile, note: nil, model: settings.value.model.rawValue,
                                   explain: settings.value.explainLanguage.rawValue)
        let started = Date()
        do {
            let (response, latency) = try await ProxyClient.shared.check(request)
            let total = Int(Date().timeIntervalSince(started) * 1000)
            var lines = ["status: \(response.status)"]
            if let corrected = response.corrected { lines.append("corrected: \(corrected)") }
            if let tip = response.tip, !tip.isEmpty { lines.append("tip: \(tip)") }
            lines.append("model time: \(latency.map { "\($0) ms" } ?? "n/a") · total: \(total) ms")
            result = lines.joined(separator: "\n")
        } catch {
            result = error.localizedDescription
        }
    }
}
