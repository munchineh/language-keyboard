import XCTest
import SwiftUI
import UIKit

// Renders the keyboard in each mockup state, in light and dark, to PNGs.
// CI sets SNAPSHOT_DIR (via TEST_RUNNER_SNAPSHOT_DIR) and uploads the folder.
// The Keyboard and Shared sources are compiled into this test target.

@MainActor
final class KeyboardSnapshotTests: XCTestCase {
    private struct Scenario {
        let name: String
        let typed: String
        var marked: String = ""
        let reply: String
        let configure: @MainActor (KeyboardModel) -> Void
    }

    private var states: [Scenario] { [
        Scenario(name: "01-typing", typed: "친구랑 영화 보", reply: "이번 주말에 뭐 해?") {
            $0.setWordForPreview("보")
        },
        Scenario(name: "02-correction", typed: "응, 어제 선생님한테 책을 줬어.", reply: "선생님한테 책 돌려줬어?") {
            $0.check = .fix(original: "응, 어제 선생님한테 책을 줬어.",
                            corrected: "응, 어제 선생님께 책을 드렸어.",
                            tip: "Talking about a teacher, even in 반말: 한테 → 께, 주다 → 드리다")
        },
        Scenario(name: "03-correction-korean-reason", typed: "응, 어제 선생님한테 책을 줬어.", reply: "선생님한테 책 돌려줬어?") {
            $0.settings.explainLanguage = .korean
            $0.check = .fix(original: "응, 어제 선생님한테 책을 줬어.",
                            corrected: "응, 어제 선생님께 책을 드렸어.",
                            tip: "반말이어도 선생님 얘기라서 한테 → 께, 주다 → 드리다로 써요")
        },
        Scenario(name: "04-looks-good", typed: "친구랑 영화 보러 갈 거야.", reply: "이번 주말에 뭐 해?") {
            $0.check = .ok(text: "친구랑 영화 보러 갈 거야.")
        },
        Scenario(name: "05-more-natural", typed: "그런데 그것은 정말 좋습니다.", reply: "새로 생긴 카페 가 봤어?") {
            $0.check = .stiff(text: "그런데 그것은 정말 좋습니다.")
        },
        Scenario(name: "06-rephrase", typed: "그런데 그것은 정말 좋습니다.", reply: "새로 생긴 카페 가 봤어?") {
            $0.check = .rephrased(original: "그런데 그것은 정말 좋습니다.",
                                  option: RephraseOption(label: "Natural", text: "근데 거기 진짜 좋아.", note: "근데 and 거기 are how people say it in chat"))
        },
        Scenario(name: "07-settings-korean", typed: "친구랑 영화 보러 갈 거야", reply: "이번 주말에 뭐 해?") {
            $0.settings.updateContext(for: .korean) { $0.speakingTo = "선배"; $0.listenerAge = .older }
            $0.openSettings()
        },
        Scenario(name: "08-settings-chinese", typed: "", reply: "你週末要幹嘛？") {
            $0.settings.language = .chinese
            $0.openSettings()
        },
        Scenario(name: "09-typing-in-settings", typed: "친구랑 영화 보러 갈 거야", reply: "이번 주말에 뭐 해?") {
            $0.openSettings()
            $0.beginEditing(.speakingTo)
            $0.fieldText = "회사 선배"
        },
        Scenario(name: "10-chinese-pinyin", typed: "", marked: "nihao", reply: "你週末要幹嘛？") {
            $0.settings.language = .chinese
            $0.setPinyinForPreview("nihao")
        },
        Scenario(name: "11-emoji", typed: "ㅋㅋㅋ", reply: "이번 주말에 뭐 해?") {
            $0.settings.recentEmoji = ["😂", "👍", "🥹", "🙏", "😭", "❤️", "🔥", "🤣", "😊", "👀"]
            $0.page = .emoji
        },
        Scenario(name: "12-numbers", typed: "3시에", reply: "몇 시에 만나?") {
            $0.page = .numbers
        },
        Scenario(name: "13-full-access-off", typed: "안녕히", reply: "잘 가!") {
            $0.fullAccessOverride = false
            $0.check = .needsFullAccess
        },
        Scenario(name: "14-settings-full-access-off", typed: "", reply: "이번 주말에 뭐 해?") {
            $0.fullAccessOverride = false
            $0.openSettings()
        },
    ] }

    func testRenderStates() throws {
        guard let dir = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"], !dir.isEmpty else {
            throw XCTSkip("SNAPSHOT_DIR not set")
        }
        let folder = URL(fileURLWithPath: dir)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        for dark in [false, true] {
            for state in states {
                let defaults = UserDefaults(suiteName: "snapshots-\(UUID().uuidString)")!
                let model = KeyboardModel(store: SettingsStore(defaults: defaults))
                model.isDark = dark
                model.fullAccessOverride = true
                model.loadResources(synchronously: true)
                state.configure(model)
                let screen = SnapshotScreen(model: model, typed: state.typed, marked: state.marked, reply: state.reply)
                let image = try render(screen, dark: dark)
                let file = folder.appendingPathComponent("\(dark ? "dark" : "light")-\(state.name).png")
                try XCTUnwrap(image.pngData()).write(to: file)
            }
        }
    }

    private func render<V: View>(_ view: V, dark: Bool) throws -> UIImage {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let host = UIHostingController(rootView: view)
        host.overrideUserInterfaceStyle = dark ? .dark : .light
        let width: CGFloat = 390
        let size = host.sizeThatFits(in: CGSize(width: width, height: 2000))
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: width, height: size.height)
        window.overrideUserInterfaceStyle = dark ? .dark : .light
        window.rootViewController = host
        window.isHidden = false
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))

        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let image = UIGraphicsImageRenderer(bounds: host.view.bounds, format: format).image { _ in
            host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
        }
        window.isHidden = true
        return image
    }
}

/// A chat screen around the keyboard, like the mockup frames.
private struct SnapshotScreen: View {
    @ObservedObject var model: KeyboardModel
    let typed: String
    let marked: String
    let reply: String

    private var theme: KeyboardTheme { KeyboardTheme(isDark: model.isDark) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(reply)
                    .font(.system(size: 16))
                    .foregroundStyle(theme.text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 6, bottomTrailingRadius: 20, topTrailingRadius: 20)
                            .fill(model.isDark ? Color(white: 0.17) : Color(white: 0.91))
                    )
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 16)
            .padding(.bottom, 12)

            HStack(spacing: 8) {
                HStack(spacing: 1) {
                    Text(typed).font(.system(size: 16)).foregroundStyle(theme.text)
                    if !marked.isEmpty {
                        Text(marked).font(.system(size: 16)).foregroundStyle(theme.text).underline()
                    }
                    Rectangle().fill(theme.accent).frame(width: 2, height: 19)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 38)
                .overlay(Capsule().strokeBorder(theme.divider, lineWidth: 1))
                Circle().fill(theme.accent).frame(width: 34, height: 34)
                    .overlay(Image(systemName: "arrow.up").font(.system(size: 16, weight: .bold)).foregroundStyle(.white))
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)

            KeyboardRootView(model: model)
                .padding(.bottom, 46) // space for the system globe/mic row
                .background(
                    UnevenRoundedRectangle(topLeadingRadius: KeyMetrics.keyboardRadius, bottomLeadingRadius: 46,
                                           bottomTrailingRadius: 46, topTrailingRadius: KeyMetrics.keyboardRadius)
                        .fill(theme.snapshotPlatter)
                )
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
        }
        .frame(width: 390)
        .background(model.isDark ? Color.black : Color.white)
    }
}
