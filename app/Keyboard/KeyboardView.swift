import SwiftUI
import UIKit

struct KeyboardRootView: View {
    @ObservedObject var model: KeyboardModel

    private var theme: KeyboardTheme { KeyboardTheme(isDark: model.isDark) }
    /// Bar plus four key rows, so the settings panel takes the same space.
    static let bodyHeight: CGFloat = KeyMetrics.barHeight + 6 + KeyMetrics.rowHeight * 4 + 4

    var body: some View {
        VStack(spacing: 0) {
            switch model.panel {
            case .keys:
                ResultCard(model: model, theme: theme)
                SuggestionBar(model: model, theme: theme)
                    .frame(height: KeyMetrics.barHeight)
                KeyGrid(model: model, theme: theme)
                    .padding(.top, 6)
                    .padding(.bottom, 4)
            case .settings:
                SettingsPanel(model: model, theme: theme)
                    .frame(height: Self.bodyHeight)
            }
        }
        .padding(.top, 6)
        .frame(maxWidth: .infinity)
        .environment(\.colorScheme, model.isDark ? .dark : .light)
    }
}

// MARK: - Suggestion bar

struct SuggestionBar: View {
    @ObservedObject var model: KeyboardModel
    let theme: KeyboardTheme

    var body: some View {
        HStack(spacing: 0) {
            Button {
                model.panel = .settings
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 19, weight: .regular))
                        .frame(width: 52, height: 40)
                    Text(model.language.badge)
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(RoundedRectangle(cornerRadius: 6).fill(theme.chip))
                        .offset(x: -2, y: -2)
                }
                .foregroundStyle(theme.text.opacity(0.85))
            }
            .accessibilityLabel("Keyboard settings and language, current \(model.language.badge)")

            Rectangle().fill(theme.divider).frame(width: 1, height: 22)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 12)
                .padding(.trailing, 4)
        }
        .padding(.horizontal, 6)
    }

    @ViewBuilder private var content: some View {
        switch model.bar {
        case .idle:
            Text(model.summary)
                .font(.system(size: 15))
                .foregroundStyle(theme.tertiaryText)
                .lineLimit(1)
        case .checking:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Checking…").font(.system(size: 15)).foregroundStyle(theme.secondaryText)
            }
        case .ok(let stiff, _):
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(theme.good)
                    .font(.system(size: 18))
                Text(model.summary)
                    .font(.system(size: 15))
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if stiff {
                    Button("More natural ›") { model.rephrase() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.accent)
                }
            }
        case .fix(let original, let corrected, _):
            HStack(spacing: 8) {
                let count = TextDiff.changeCount(old: original, new: corrected)
                Text("\(count) \(count == 1 ? "fix" : "fixes") · \(model.summary)")
                    .font(.system(size: 15))
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(1)
                Spacer(minLength: 4)
                CapsuleButton(title: "Apply", theme: theme) { model.applyCorrection() }
            }
        case .rephrasing:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Finding a more natural way…").font(.system(size: 15)).foregroundStyle(theme.secondaryText)
            }
        case .options:
            HStack {
                Text("Pick one").font(.system(size: 15)).foregroundStyle(theme.secondaryText)
                Spacer()
                Button("Keep mine") { model.dismissResult() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.accent)
            }
        case .message(let text):
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(theme.fixHighlight)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
    }
}

struct CapsuleButton: View {
    let title: String
    let theme: KeyboardTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .frame(height: 34)
                .background(Capsule().fill(theme.accent))
        }
    }
}

// MARK: - Card above the bar (correction, rephrase options)

struct ResultCard: View {
    @ObservedObject var model: KeyboardModel
    let theme: KeyboardTheme

    var body: some View {
        switch model.bar {
        case .fix(let original, let corrected, let tip):
            card {
                VStack(alignment: .leading, spacing: 4) {
                    highlighted(old: original, new: corrected)
                        .font(.system(size: 15))
                        .fixedSize(horizontal: false, vertical: true)
                    if !tip.isEmpty {
                        Text(tip)
                            .font(.system(size: 13))
                            .foregroundStyle(theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        case .options(let original, let options):
            card {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(options) { option in
                        Button { model.choose(option) } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(option.label.uppercased())
                                    .font(.system(size: 11, weight: .semibold))
                                    .tracking(0.5)
                                    .foregroundStyle(theme.tertiaryText)
                                highlighted(old: original, new: option.text)
                                    .font(.system(size: 15))
                                    .fixedSize(horizontal: false, vertical: true)
                                if let note = option.note, !note.isEmpty {
                                    Text(note)
                                        .font(.system(size: 13))
                                        .foregroundStyle(theme.secondaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        default:
            EmptyView()
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(theme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(theme.keyHighlight.opacity(0.5), lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, 10)
            .padding(.top, 2)
            .padding(.bottom, 6)
    }

    /// The new text with changed parts in orange, as in the mockup.
    private func highlighted(old: String, new: String) -> Text {
        var result = AttributedString()
        for segment in TextDiff.segments(old: old, new: new) {
            var piece = AttributedString(segment.text)
            piece.foregroundColor = segment.changed ? theme.fixHighlight : theme.text
            if segment.changed { piece.font = .system(size: 15, weight: .semibold) }
            result += piece
        }
        return Text(result)
    }
}

// MARK: - Keys

struct KeyGrid: View {
    @ObservedObject var model: KeyboardModel
    let theme: KeyboardTheme

    var body: some View {
        let rows = KeyLayouts.rows(language: model.language, page: model.page, showGlobe: model.showGlobe)
        VStack(spacing: 0) {
            ForEach(rows) { row in
                HStack(spacing: 0) {
                    ForEach(row.keys) { key in
                        KeyView(key: key, model: model, theme: theme)
                            .padding(.leading, key.leadingGap)
                            .padding(.trailing, key.trailingGap)
                    }
                }
                // Keys draw inset by half a gap, so the touch areas meet with no dead space.
                .padding(.horizontal, max(0, row.inset - KeyMetrics.horizontalGap / 2))
                .frame(height: KeyMetrics.rowHeight)
            }
        }
    }
}

struct KeyView: View {
    let key: Key
    @ObservedObject var model: KeyboardModel
    let theme: KeyboardTheme

    var body: some View {
        Group {
            switch key.kind {
            case .nextKeyboard:
                if let controller = model.controller {
                    NextKeyboardButton(controller: controller, tint: UIColor(theme.text))
                        .frame(width: 44)
                        .padding(.horizontal, KeyMetrics.horizontalGap / 2)
                } else {
                    Color.clear
                }
            case .text("", _):
                Color.clear
            default:
                KeyCap(isFunction: isFunction, repeats: key.kind == .delete, theme: theme, isActive: isActive) {
                    model.tap(key.kind)
                } label: {
                    label
                }
            }
        }
        .frame(maxWidth: maxWidth)
        .frame(width: fixedWidth)
    }

    private var fixedWidth: CGFloat? {
        if case .fixed(let w) = key.width { return w + KeyMetrics.horizontalGap }
        return nil
    }

    private var maxWidth: CGFloat? {
        if case .flex = key.width { return .infinity }
        return nil
    }

    private var isFunction: Bool {
        switch key.kind {
        case .text, .space: return false
        default: return true
        }
    }

    private var isActive: Bool { key.kind == .shift && model.shift }

    @ViewBuilder private var label: some View {
        switch key.kind {
        case .text(let s, let shifted):
            Text(model.shift ? (shifted ?? s) : s)
                .font(.system(size: 22))
        case .shift:
            Image(systemName: model.shift ? "shift.fill" : "shift").font(.system(size: 19))
        case .delete:
            Image(systemName: "delete.left").font(.system(size: 19))
        case .numbers:
            Text("123").font(.system(size: 17))
        case .letters:
            Text(model.language == .korean ? "가" : "ABC").font(.system(size: 17))
        case .languageToggle:
            // Shows the language it switches to.
            let next = KeyboardLanguage.allCases.first { $0 != model.language } ?? model.language
            Text(next.badge).font(.system(size: 17))
        case .space:
            Text(model.language.name)
                .font(.system(size: 14))
                .foregroundStyle(theme.tertiaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 10)
                .padding(.bottom, 6)
        case .returnKey:
            if model.returnLabel.isEmpty {
                Image(systemName: "return").font(.system(size: 19))
            } else {
                Text(model.returnLabel).font(.system(size: 16))
            }
        case .nextKeyboard:
            EmptyView()
        }
    }
}

/// One key. Letters fire on release; delete fires on press and repeats while held.
struct KeyCap<Label: View>: View {
    let isFunction: Bool
    let repeats: Bool
    let theme: KeyboardTheme
    var isActive = false
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    @State private var pressed = false
    @State private var repeatTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: KeyMetrics.cornerRadius, style: .continuous)
                .fill(fill)
                .shadow(color: theme.keyShadow, radius: 0, x: 0, y: 1)
                .overlay(
                    RoundedRectangle(cornerRadius: KeyMetrics.cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(colors: [theme.keyHighlight, .clear], startPoint: .top, endPoint: .center),
                            lineWidth: 0.5
                        )
                )
            label()
                .foregroundStyle(theme.text)
        }
        .padding(.horizontal, KeyMetrics.horizontalGap / 2)
        .padding(.vertical, KeyMetrics.verticalGap / 2)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !pressed else { return }
                    pressed = true
                    if repeats {
                        action()
                        startRepeating()
                    }
                }
                .onEnded { _ in
                    pressed = false
                    stopRepeating()
                    if !repeats { action() }
                }
        )
        .onDisappear { stopRepeating() }
    }

    private var fill: Color {
        if isActive { return isFunction ? theme.functionKeyPressed : theme.keyPressed }
        if pressed { return isFunction ? theme.functionKeyPressed : theme.keyPressed }
        return isFunction ? theme.functionKey : theme.key
    }

    private func startRepeating() {
        stopRepeating()
        repeatTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            while !Task.isCancelled {
                action()
                try? await Task.sleep(nanoseconds: 80_000_000)
            }
        }
    }

    private func stopRepeating() {
        repeatTask?.cancel()
        repeatTask = nil
    }
}

/// The globe key needs UIKit's target-action so the system can show the keyboard list.
struct NextKeyboardButton: UIViewRepresentable {
    let controller: UIInputViewController
    let tint: UIColor

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "globe"), for: .normal)
        button.addTarget(controller, action: #selector(UIInputViewController.handleInputModeList(from:with:)), for: .allTouchEvents)
        button.accessibilityLabel = "Next keyboard"
        return button
    }

    func updateUIView(_ button: UIButton, context: Context) {
        button.tintColor = tint
    }
}
