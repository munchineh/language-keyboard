import SwiftUI

@main
struct LanguageKeyboardApp: App {
    @StateObject private var settings = AppSettings()
    @State private var tab = Tab.setup

    enum Tab { case setup, writing, checks }

    var body: some Scene {
        WindowGroup {
            TabView(selection: $tab) {
                SetupView()
                    .tabItem { Label("Set up", systemImage: "keyboard") }
                    .tag(Tab.setup)
                WritingView()
                    .tabItem { Label("Writing", systemImage: "text.bubble") }
                    .tag(Tab.writing)
                ConnectionView()
                    .tabItem { Label("Checks", systemImage: "checkmark.bubble") }
                    .tag(Tab.checks)
            }
            .environmentObject(settings)
            .onOpenURL(perform: handle)
        }
    }

    /// Links from the keyboard: "checks" opens the Checks tab (token);
    /// "full-access" goes straight to this app's page in Settings
    /// (Keyboards › Allow Full Access).
    private func handle(_ url: URL) {
        guard url.scheme == "languagekeyboard" else { return }
        switch url.host {
        case "checks":
            tab = .checks
        case "full-access":
            tab = .setup
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        default:
            tab = .setup
        }
    }
}

/// The companion app's view of the shared settings. Saves on every change.
@MainActor
final class AppSettings: ObservableObject {
    private let store = SettingsStore.shared

    @Published var value: KeyboardSettings { didSet { store.save(value) } }
    @Published var proxyURL: String { didSet { store.proxyURL = proxyURL } }
    @Published var proxyToken: String { didSet { store.proxyToken = proxyToken } }

    init() {
        value = store.load()
        proxyURL = store.proxyURL
        proxyToken = store.proxyToken
    }

    /// Pick up changes the keyboard made while the app was in the background.
    func reload() {
        let latest = store.load()
        if latest != value { value = latest }
    }
}
