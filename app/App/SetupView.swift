import SwiftUI
import UIKit

/// Setup that ticks itself off, styled like an iOS Settings page: coloured
/// icon tiles, grey "Off" on the right until a step is done, then a green tick.
struct SetupView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var keyboardAdded = false
    @State private var fullAccess = false
    @State private var tryText = ""

    /// Re-checks every second while the screen is open, so ticks appear as soon as
    /// you come back from Settings or open the keyboard in "Try it".
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var allDone: Bool { keyboardAdded && fullAccess }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    statusRow(symbol: "keyboard", tint: Color(.systemGray),
                              title: AppName.display,
                              detail: keyboardAdded ? nil : "Settings › Keyboards › \(AppName.display)",
                              done: keyboardAdded)
                    statusRow(symbol: "network", tint: .blue,
                              title: "Allow Full Access",
                              detail: fullAccess ? nil : "Lets the keyboard check your sentences. Ticks once you've opened the keyboard below.",
                              done: fullAccess)
                    if !allDone {
                        Button("Open Settings") {
                            // iOS doesn't let apps open the Keyboards screen directly; this opens
                            // the app's own Settings page, which has the Keyboards switches on it.
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                } header: {
                    Text(allDone ? "You're all set" : "Set up")
                } footer: {
                    Text(allDone
                         ? "To switch keyboards in any app, tap and hold the 🌐 key under the keyboard."
                         : "Your iPhone shows a general warning for Full Access, as it does for any keyboard that goes online. Your text is only used for the check and isn't saved.")
                }

                Section {
                    TextField("Type a sentence in Korean or Chinese", text: $tryText, axis: .vertical)
                        .lineLimit(3...6)
                    if !tryText.isEmpty {
                        Button("Clear", role: .destructive) { tryText = "" }
                    }
                } header: {
                    Text("Try it")
                } footer: {
                    Text("Tap the box, hold 🌐 and pick \(AppName.display). Stop typing for a moment, or end a sentence with . ? or !, and the keyboard checks it.")
                }
            }
            .navigationTitle(AppName.display)
            .animation(.default, value: keyboardAdded)
            .animation(.default, value: fullAccess)
            .onAppear(perform: refresh)
            .onReceive(timer) { _ in if scenePhase == .active { refresh() } }
            .onChange(of: scenePhase) { _, phase in if phase == .active { refresh() } }
        }
    }

    private func refresh() {
        let seen = SettingsStore.shared.keyboardSeenWithFullAccess
        fullAccess = seen
        keyboardAdded = seen || KeyboardSetupCheck.isKeyboardAdded
    }

    private func statusRow(symbol: String, tint: Color, title: String, detail: String?, done: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 29, height: 29)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(tint))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let detail {
                    Text(detail).font(.footnote).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if done {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityLabel("Done")
            } else {
                Text("Off").foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

/// Whether Language Keyboard is in the user's keyboard list.
enum KeyboardSetupCheck {
    static let keyboardBundleID = "com.mancinitan.LanguageKeyboard.Keyboard"

    static var isKeyboardAdded: Bool {
        // The enabled keyboards are listed in the shared "AppleKeyboards" preference.
        if let ids = UserDefaults.standard.array(forKey: "AppleKeyboards") as? [String],
           ids.contains(where: { $0.hasPrefix(keyboardBundleID) }) {
            return true
        }
        // Fallback: the active input modes, when they expose an identifier.
        let selector = NSSelectorFromString("identifier")
        return UITextInputMode.activeInputModes.contains { mode in
            guard mode.responds(to: selector) else { return false }
            return (mode.value(forKey: "identifier") as? String)?.hasPrefix(keyboardBundleID) == true
        }
    }
}

#Preview {
    SetupView()
}
