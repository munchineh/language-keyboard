import SwiftUI

/// The keyboard's own emoji page. A third-party keyboard can't open Apple's
/// emoji keyboard, so this replaces it: recents, the Unicode groups, a
/// category row to jump between them, and delete.
struct EmojiPanel: View {
    @ObservedObject var model: KeyboardModel
    let theme: KeyboardTheme

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 8)

    var body: some View {
        let groups = model.emoji?.groups ?? []
        ScrollViewReader { scroller in
            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        if !model.settings.recentEmoji.isEmpty {
                            section("Recent", model.settings.recentEmoji).id("Recent")
                        }
                        ForEach(groups) { group in
                            section(group.name, group.emoji).id(group.name)
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .frame(height: KeyMetrics.rowHeight * 3)

                HStack(spacing: 0) {
                    KeyCap(isFunction: true, repeats: false, theme: theme) {
                        model.tap(.letters)
                    } label: {
                        Text(model.language == .korean ? "가" : "拼").font(.system(size: 17))
                    }
                    .frame(width: 60 + KeyMetrics.horizontalGap)

                    HStack(spacing: 0) {
                        if !model.settings.recentEmoji.isEmpty {
                            categoryButton("clock", id: "Recent", scroller: scroller)
                        }
                        ForEach(groups) { group in
                            categoryButton(group.symbol, id: group.name, scroller: scroller)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    KeyCap(isFunction: true, repeats: true, theme: theme) {
                        model.tap(.delete)
                    } label: {
                        Image(systemName: "delete.left")
                            .symbolRenderingMode(.hierarchical)
                            .font(.system(size: 19))
                    }
                    .frame(width: 46 + KeyMetrics.horizontalGap)
                }
                .padding(.horizontal, 1)
                .frame(height: KeyMetrics.rowHeight)
            }
        }
    }

    private func section(_ title: String, _ emoji: [String]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(theme.tertiaryText)
                .padding(.leading, 4)
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(emoji, id: \.self) { e in
                    Button { model.typeEmoji(e) } label: {
                        Text(e)
                            .font(.system(size: 30))
                            .frame(maxWidth: .infinity, minHeight: 42)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func categoryButton(_ symbol: String, id: String, scroller: ScrollViewProxy) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) { scroller.scrollTo(id, anchor: .top) }
        } label: {
            Image(systemName: symbol)
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 15))
                .foregroundStyle(theme.secondaryText)
                .frame(maxWidth: .infinity, minHeight: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(id)
    }
}
