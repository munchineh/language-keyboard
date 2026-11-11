import UIKit
import SwiftUI

/// Keyboard extension entry point. Hosts the SwiftUI keyboard and passes it
/// the text document proxy.
final class KeyboardViewController: UIInputViewController {
    private let model = KeyboardModel()
    private var hosting: UIHostingController<KeyboardRootView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        model.controller = self

        let host = UIHostingController(rootView: KeyboardRootView(model: model))
        host.sizingOptions = .intrinsicContentSize
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(host)
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        host.didMove(toParent: self)
        hosting = host

        // Let the keyboard grow when the correction card appears.
        inputView?.allowsSelfSizing = true

        // Follow light/dark changes while the keyboard is open.
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (controller: KeyboardViewController, _: UITraitCollection) in
            controller.updateAppearance()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        model.reload()
        updateAppearance()
        if hasFullAccess { SettingsStore.shared.markKeyboardSeenWithFullAccess() }
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        if model.showGlobe != needsInputModeSwitchKey { model.showGlobe = needsInputModeSwitchKey }
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        updateAppearance()
        model.textDidChange()
    }

    private func updateAppearance() {
        let dark: Bool
        switch textDocumentProxy.keyboardAppearance ?? .default {
        case .dark: dark = true
        case .light: dark = false
        default: dark = traitCollection.userInterfaceStyle == .dark
        }
        if model.isDark != dark { model.isDark = dark }
        // Native controls (segmented pickers) follow UIKit's style, not SwiftUI's.
        hosting?.overrideUserInterfaceStyle = dark ? .dark : .light
    }
}
