import Foundation

/// The app's user-facing name. Placeholder until the real name is chosen:
/// change APP_DISPLAY_NAME in project.yml and every screen follows.
enum AppName {
    static let display: String =
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Language Keyboard"
}
