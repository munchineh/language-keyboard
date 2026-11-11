import SwiftUI

@main
struct LanguageKeyboardApp: App {
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            TabView {
                SetupView()
                    .tabItem { Label("Set up", systemImage: "keyboard") }
                ProfilesView()
                    .tabItem { Label("Profiles", systemImage: "person.2") }
                ConnectionView()
                    .tabItem { Label("Checks", systemImage: "checkmark.bubble") }
            }
            .environmentObject(settings)
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
