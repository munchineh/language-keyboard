import SwiftUI
import UIKit

struct SetupView: View {
    @State private var tryText = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        // iOS doesn't let apps open the Keyboards screen directly; this opens
                        // the app's own Settings page, which has the Keyboards switch on it.
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Open Settings", systemImage: "gear")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

                    step(1, "Open Settings",
                         "Tap the button above. Settings opens on this app's page.")
                    step(2, "Turn on the keyboard",
                         "Tap Keyboards, then switch on Language Keyboard. It joins the keyboards you already use.")
                    step(3, "Turn on Allow Full Access",
                         "On the same screen. This lets the keyboard check your sentences as you type. Your iPhone shows a general warning here, as it does for any keyboard that goes online. Your text is only used for the check and isn't saved.")
                    step(4, "Start typing",
                         "In any app, tap and hold the 🌐 key under the keyboard and pick Language Keyboard.")
                } header: {
                    Text("Set up your keyboard")
                }

                Section {
                    TextField("Type a sentence in Korean or Chinese", text: $tryText, axis: .vertical)
                        .lineLimit(3...6)
                        .focused($focused)
                    if !tryText.isEmpty {
                        Button("Clear", role: .destructive) { tryText = "" }
                    }
                } header: {
                    Text("Try it")
                } footer: {
                    Text("Stop typing for a moment, or end a sentence with . ? or !, and the keyboard checks it. Suggested fixes appear just above the keys.")
                }
            }
            .navigationTitle("Language Keyboard")
        }
    }

    private func step(_ number: Int, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.accentColor))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold))
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    SetupView()
}
