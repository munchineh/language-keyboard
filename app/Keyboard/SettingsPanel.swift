import SwiftUI

/// "Check settings", opened from the left icon in the bar. Replaces the keys
/// while open, as in the mockup.
struct SettingsPanel: View {
    @ObservedObject var model: KeyboardModel
    let theme: KeyboardTheme

    private var profile: Profile { model.settings.activeProfile(for: model.language) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Check settings")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.text)
                Spacer()
                Button {
                    model.panel = .keys
                } label: {
                    Text("Done")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.text)
                        .padding(.horizontal, 16)
                        .frame(height: 32)
                        .background(Capsule().fill(theme.segmentSelected))
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 10)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    section("Language") {
                        Segmented(options: KeyboardLanguage.allCases, selection: model.language, label: { $0.name }, theme: theme) {
                            model.setLanguage($0)
                        }
                    }

                    section("Speaking to") {
                        FlowChips(items: model.settings.profiles(for: model.language), selected: profile, label: { $0.name }, theme: theme) {
                            model.selectProfile($0)
                        }
                    }

                    if model.language == .korean {
                        section("Speech level") {
                            Segmented(options: SpeechLevel.allCases, selection: profile.speechLevel, label: { $0.label }, theme: theme) { level in
                                model.updateProfile { $0.speechLevel = level }
                            }
                        }
                        HStack(alignment: .top, spacing: 10) {
                            section("They are") {
                                Segmented(options: RelativeAge.allCases, selection: profile.listenerAge, label: { $0.label }, theme: theme) { age in
                                    model.updateProfile { $0.listenerAge = age }
                                }
                            }
                            .layoutPriority(3)
                            section("Their gender") {
                                Segmented(options: Gender.allCases, selection: profile.listenerGender, label: { $0.short }, theme: theme) { gender in
                                    // Tap the selected one again to clear it.
                                    model.updateProfile { $0.listenerGender = $0.listenerGender == gender ? nil : gender }
                                }
                            }
                            .layoutPriority(2)
                        }
                    } else {
                        HStack(alignment: .top, spacing: 10) {
                            section("Region") {
                                Segmented(options: ChineseRegion.allCases, selection: model.settings.region, label: { $0.label }, theme: theme) { region in
                                    model.update { $0.region = region }
                                }
                            }
                            section("Script") {
                                Segmented(options: ChineseScript.allCases, selection: model.settings.script, label: { $0.label }, theme: theme) { script in
                                    model.update { $0.script = script }
                                }
                            }
                        }
                    }

                    section("Tone") {
                        FlowChips(items: Tone.allCases, selected: profile.tone, label: { $0.label }, theme: theme) { tone in
                            model.updateProfile { $0.tone = tone }
                        }
                    }

                    section("What I mean") {
                        Text(model.settings.note.isEmpty
                             ? "Add a note in the Language Keyboard app"
                             : "“\(model.settings.note)”")
                            .font(.system(size: 15))
                            .foregroundStyle(theme.secondaryText)
                            .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
                            .padding(.horizontal, 12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(theme.segmentTrack))
                    }

                    if !model.hasFullAccess {
                        Text("Full Access is off: checks are paused and changes here aren't saved.")
                            .font(.system(size: 13))
                            .foregroundStyle(theme.fixHighlight)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(theme.secondaryText)
            content()
        }
    }
}

/// Segmented control styled like the mockup.
struct Segmented<Option: Hashable>: View {
    let options: [Option]
    let selection: Option?
    let label: (Option) -> String
    let theme: KeyboardTheme
    let onSelect: (Option) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                let selected = option == selection
                Button { onSelect(option) } label: {
                    Text(label(option))
                        .font(.system(size: 14, weight: selected ? .semibold : .regular))
                        .lineLimit(1)
                        .foregroundStyle(theme.text)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background(RoundedRectangle(cornerRadius: 11).fill(selected ? theme.segmentSelected : .clear))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 14).fill(theme.segmentTrack))
    }
}

/// Wrapping row of chips (profiles, tone).
struct FlowChips<Item: Hashable>: View {
    let items: [Item]
    let selected: Item?
    let label: (Item) -> String
    let theme: KeyboardTheme
    let onSelect: (Item) -> Void

    var body: some View {
        WrapLayout(spacing: 8) {
            ForEach(items, id: \.self) { item in
                let isOn = item == selected
                Button { onSelect(item) } label: {
                    Text(label(item))
                        .font(.system(size: 14, weight: isOn ? .semibold : .regular))
                        .foregroundStyle(isOn ? .white : theme.text)
                        .padding(.horizontal, 14)
                        .frame(height: 32)
                        .background(Capsule().fill(isOn ? theme.accent : theme.chip))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }
}

/// Minimal flow layout: places views left to right and wraps.
struct WrapLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: proposal.width ?? maxX, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
