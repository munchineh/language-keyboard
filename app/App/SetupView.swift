import SwiftUI
import UIKit

struct SetupView: View {
    @State private var tryText = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    step(1, "Open Settings", "Tap the button below. It opens this app's page in Settings.")
                    step(2, "Turn on the keyboard", "Keyboards › Language Keyboard.")
                    step(3, "Allow Full Access", "Needed for checks (they go through your proxy) and for saving settings from the keyboard. Nothing you type is stored.")
                    step(4, "Switch to it", "In any app, hold the globe key and pick Language Keyboard.")
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Open Settings", systemImage: "gear")
                    }
                } header: {
                    Text("Add the keyboard")
                }

                Section {
                    TextField("Type here to try it", text: $tryText, axis: .vertical)
                        .lineLimit(3...6)
                        .focused($focused)
                    if !tryText.isEmpty {
                        Button("Clear", role: .destructive) { tryText = "" }
                    }
                } header: {
                    Text("Try it")
                } footer: {
                    Text("Pause for a second or end a sentence with . ? ! to see a check.")
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
