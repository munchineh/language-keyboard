import Foundation

/// Shared storage between the companion app and the keyboard (App Group).
///
/// The keyboard can only write here when Full Access is on; without it,
/// changes made in the keyboard last until the keyboard closes.
enum AppGroup {
    static let id = "group.com.mancinitan.LanguageKeyboard"
    static let defaultProxyURL = "https://keyboard-proxy.mancini-tan.workers.dev"
}

final class SettingsStore {
    static let shared = SettingsStore()

    private enum Key {
        static let settings = "settings.v1"
        static let proxyURL = "proxy.url"
        // Personal use for now. Move to a shared Keychain item before going public.
        static let proxyToken = "proxy.token"
    }

    let defaults: UserDefaults

    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? UserDefaults(suiteName: AppGroup.id) ?? .standard
    }

    func load() -> KeyboardSettings {
        guard let data = defaults.data(forKey: Key.settings),
              let settings = try? JSONDecoder().decode(KeyboardSettings.self, from: data) else {
            return KeyboardSettings()
        }
        return settings
    }

    func save(_ settings: KeyboardSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Key.settings)
    }

    var proxyURL: String {
        get {
            let value = defaults.string(forKey: Key.proxyURL)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return value.isEmpty ? AppGroup.defaultProxyURL : value
        }
        set { defaults.set(newValue, forKey: Key.proxyURL) }
    }

    var proxyToken: String {
        get { defaults.string(forKey: Key.proxyToken) ?? "" }
        set { defaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Key.proxyToken) }
    }
}
