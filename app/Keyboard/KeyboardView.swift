import SwiftUI
import UIKit

struct KeyboardRootView: View {
    @ObservedObject var model: KeyboardModel

    private var theme: KeyboardTheme { KeyboardTheme(isDark: model.isDark) }

    var body: some View {
        VStack(spacing: 0) {
            if model.panel == .settings {
                SettingsPanel(model: model, theme: theme)
                    .frame(height: KeyMetrics.bodyHeight)
            } else {
                if model.editingField != nil {
                    FieldEditorBar(model: model, theme: theme)
                        .frame(height: KeyMetrics.barHeight)
                        .padding(.top, 6)
                } else {
                    if model.check.hasCard {
                        ResultCard(model: model, theme: theme)
                    }
                    SuggestionBar(model: model, theme: theme)
                        .frame(height: KeyMetrics.barHeight)
                        .padding(.top, model.check.hasCard ? 0 : 6)
                }
                Group {
                    if model.page == .emoji {
                        EmojiPanel(model: model, theme: theme)
                    } else {
                        KeyGrid(model: model, theme: theme)
                    }
                }
                .padding(.top, 6)
                .padding(.bottom, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .environment(\.colorScheme, model.isDark ? .dark : .light)
    }
}

// MARK: - Bar: settings icon + word suggestions (like Apple's predictive bar)

struct SuggestionBar: View {
    @ObservedObject var model: KeyboardModel
    let theme: KeyboardTheme

    var body: some View {
        HStack(spacing: 0) {
            Button { model.openSettings() } label: {
                SettingsGlyph(badge: model.language.badge, color: theme.text.opacity(0.85))
                    .frame(width: 56, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Check settings, \(model.language.name)")

            Rectangle().fill(theme.divider).frame(width: 1, height: 22)

            switch model.check {
            case .checking where model.suggestions.isEmpty:
                status { ProgressView().controlSize(.small) } text: { "Checking…" }
            case .ok:
                // Green only for success.
                status {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(theme.good)
                } text: { "Looks right!" }
            default:
                if model.language == .chinese { candidates } else { predictions }
            }
        }
        .padding(.horizontal, 6)
    }

    /// Check status in the space where suggestions sit.
    private func status<Icon: View>(@ViewBuilder _ icon: () -> Icon, text: () -> String) -> some View {
        HStack(spacing: 6) {
            icon()
            Text(text())
                .font(.system(size: 16))
                .foregroundStyle(theme.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Three slots, like Apple's bar. Empty slots stay blank.
    private var predictions: some View {
        HStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { i in
                if i > 0 { Rectangle().fill(theme.divider.opacity(i < model.suggestions.count ? 1 : 0)).frame(width: 1, height: 22) }
                if i < model.suggestions.count {
                    let s = model.suggestions[i]
                    Button { model.choose(s) } label: {
                        Text(s.text)
                            .font(.system(size: 17))
                            .foregroundStyle(theme.text)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear.frame(maxWidth: .infinity)
                }
            }
        }
    }

    /// Chinese candidates scroll sideways, as on Apple's pinyin keyboard.
    private var candidates: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(model.suggestions) { s in
                    Button { model.choose(s) } label: {
                        Text(s.text)
                            .font(.system(size: 19))
                            .foregroundStyle(theme.text)
                            .padding(.horizontal, 12)
                            .frame(maxHeight: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.leading, 4)
        }
    }
}

// MARK: - Card above the bar: correction, "could be more natural", options

struct ResultCard: View {
    @ObservedObject var model: KeyboardModel
    let theme: KeyboardTheme

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: KeyMetrics.cardRadius, style: .continuous)
                    .fill(theme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: KeyMetrics.cardRadius, style: .continuous)
                            .strokeBorder(theme.keyHighlight.opacity(0.5), lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, KeyMetrics.cardMargin)
            .padding(.top, KeyMetrics.cardMargin)
            .padding(.bottom, 2)
    }

    @ViewBuilder private var content: some View {
        switch model.check {
        case .fix(let original, let corrected, let tip):
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    highlighted(old: original, new: corrected)
                        .font(.system(size: 15))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    if !tip.isEmpty {
                        Text(tip)
                            .font(.system(size: 13))
                            .foregroundStyle(theme.faintText)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                ArrowButton(theme: theme) { model.applyCard() }
            }
        case .stiff:
            HStack(spacing: 10) {
                Text("Correct. Could sound more natural.")
                    .font(.system(size: 14))
                    .foregroundStyle(theme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ArrowButton(theme: theme, systemName: "arrow.right", label: "Show more natural versions") { model.rephrase() }
            }
        case .rephrasing:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Finding a more natural way…").font(.system(size: 14)).foregroundStyle(theme.secondaryText)
            }
        case .rephrased(let original, let option):
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    highlighted(old: original, new: option.text)
                        .font(.system(size: 15))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    if let note = option.note, !note.isEmpty {
                        Text(note)
                            .font(.system(size: 13))
                            .foregroundStyle(theme.faintText)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                ArrowButton(theme: theme, label: "Use this") { model.applyCard() }
            }
        case .message(let text):
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(theme.warning)
                .lineLimit(2)
        default:
            EmptyView()
        }
    }

    /// The new text with the changed parts in blue.
    private func highlighted(old: String, new: String) -> Text {
        var result = AttributedString()
        for segment in TextDiff.segments(old: old, new: new) {
            var piece = AttributedString(segment.text)
            piece.foregroundColor = segment.changed ? theme.highlight : theme.text
            if segment.changed { piece.font = .system(size: 15, weight: .semibold) }
            result += piece
        }
        return Text(result)
    }
}

// MARK: - Typing into a settings field ("Speaking to", "What I mean")

struct FieldEditorBar: View {
    @ObservedObject var model: KeyboardModel
    let theme: KeyboardTheme

    var body: some View {
        let field = model.editingField ?? .speakingTo
        HStack(spacing: 10) {
            Text(field.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.secondaryText)
            HStack(spacing: 1) {
                Text(model.fieldText.isEmpty ? field.placeholder : model.fieldText)
                    .font(.system(size: 16))
                    .foregroundStyle(model.fieldText.isEmpty ? theme.tertiaryText : theme.text)
                    .lineLimit(1)
                    .truncationMode(.head)
                Rectangle().fill(theme.accent).frame(width: 2, height: 19)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(theme.segmentTrack))
            Button { model.finishEditingField() } label: {
                Text("Done")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 32)
                    .background(Capsule().fill(theme.accent))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
    }
}

// MARK: - Keys

struct KeyGrid: View {
    @ObservedObject var model: KeyboardModel
    let theme: KeyboardTheme

    var body: some View {
        let rows = KeyLayouts.rows(letters: model.letterLayout, page: model.page, language: model.language,
                                   showGlobe: model.showGlobe, editingField: model.editingField != nil)
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
                KeyCap(isFunction: isFunction, repeats: key.kind == .delete, theme: theme, isActive: isActive,
                       longPress: longPress) {
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

    /// Long-press return applies the correction.
    private var longPress: (() -> Void)? {
        guard key.kind == .returnKey, model.canQuickApply else { return nil }
        return { model.quickApply() }
    }

    @ViewBuilder private var label: some View {
        switch key.kind {
        case .text(let s, let shifted):
            Text(model.shift ? (shifted ?? s) : s)
                .font(.system(size: 22))
        case .shift:
            Image(systemName: model.shift ? "shift.fill" : "shift").font(.system(size: 19))
        case .delete:
            Image(systemName: "delete.left")
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 19))
        case .numbers:
            Text("123").font(.system(size: 17))
        case .letters:
            Text(model.letterLayout == .hangul ? "가" : (model.language == .chinese && model.editingField == nil ? "拼" : "ABC"))
                .font(.system(size: 17))
        case .emoji:
            Image(systemName: "face.smiling")
                .font(.system(size: 21, weight: .light))
                .accessibilityLabel("Emoji")
        case .fieldLayoutToggle:
            Text(model.fieldLatin ? "한" : "ABC").font(.system(size: 16))
        case .space:
            Text(model.editingField != nil ? "space" : model.language.name)
                .font(.system(size: 14))
                .foregroundStyle(theme.tertiaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 10)
                .padding(.bottom, 6)
        case .returnKey:
            if model.editingField != nil {
                Text("Done").font(.system(size: 16))
            } else if model.returnLabel.isEmpty {
                // Blue while a correction is ready: hold to apply it.
                Image(systemName: "return")
                    .font(.system(size: 19, weight: model.canQuickApply ? .semibold : .regular))
                    .foregroundStyle(model.canQuickApply ? theme.accent : theme.text)
            } else {
                Text(model.returnLabel).font(.system(size: 16))
                    .foregroundStyle(model.canQuickApply ? theme.accent : theme.text)
            }
        case .nextKeyboard:
            EmptyView()
        }
    }
}

/// One key. Letters fire on release; delete fires on press and repeats while held;
/// a key with `longPress` runs it after 0.45s held instead of its tap action.
struct KeyCap<Label: View>: View {
    let isFunction: Bool
    let repeats: Bool
    let theme: KeyboardTheme
    var isActive = false
    var longPress: (() -> Void)? = nil
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    @State private var pressed = false
    @State private var holdTask: Task<Void, Never>?
    @State private var longPressFired = false

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
                    longPressFired = false
                    if repeats {
                        action()
                        startRepeating()
                    } else if let longPress {
                        holdTask = Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 450_000_000)
                            guard !Task.isCancelled else { return }
                            longPressFired = true
                            longPress()
                        }
                    }
                }
                .onEnded { _ in
                    pressed = false
                    stopHold()
                    if !repeats && !longPressFired { action() }
                }
        )
        .onDisappear { stopHold() }
    }

    private var fill: Color {
        if isActive || pressed { return isFunction ? theme.functionKeyPressed : theme.keyPressed }
        return isFunction ? theme.functionKey : theme.key
    }

    private func startRepeating() {
        stopHold()
        holdTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            while !Task.isCancelled {
                action()
                try? await Task.sleep(nanoseconds: 80_000_000)
            }
        }
    }

    private func stopHold() {
        holdTask?.cancel()
        holdTask = nil
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
