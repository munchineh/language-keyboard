import XCTest

// The Shared sources are compiled into this test target directly (see project.yml).

final class HangulComposerTests: XCTestCase {
    /// Types a key sequence and returns the document text (committed + composing).
    private func type(_ keys: String, then backspaces: Int = 0) -> String {
        var composer = HangulComposer()
        var document = ""
        var composingLength = 0
        func apply(_ out: HangulComposer.Output) {
            document.removeLast(composingLength)
            document += out.committed + out.composing
            composingLength = out.composing.count
        }
        for k in keys { apply(composer.input(k)) }
        for _ in 0..<backspaces {
            if let out = composer.backspace() {
                apply(out)
            } else if !document.isEmpty {
                document.removeLast()
                composingLength = 0
            }
        }
        return document
    }

    func testSimpleSyllables() {
        XCTAssertEqual(type("ㅎㅏㄴㄱㅡㄹ"), "한글")
        XCTAssertEqual(type("ㅇㅏㄴㄴㅕㅇ"), "안녕")
    }

    func testFinalMovesToNextSyllable() {
        XCTAssertEqual(type("ㄱㅏㄱㅏ"), "가가")
        XCTAssertEqual(type("ㅅㅓㄴㅅㅐㅇㄴㅣㅁ"), "선생님")
    }

    func testDoubleFinalSplits() {
        XCTAssertEqual(type("ㅇㅓㅂㅅ"), "없")
        XCTAssertEqual(type("ㅇㅓㅂㅅㅇㅓ"), "없어")
        XCTAssertEqual(type("ㅇㅓㅂㅅㅓ"), "업서")
        XCTAssertEqual(type("ㅇㅣㄹㄱㅓ"), "일거")
    }

    func testCompoundVowels() {
        XCTAssertEqual(type("ㅂㅘ"), "봐") // ㅘ typed directly is not on the keyboard, but should still work
        XCTAssertEqual(type("ㅂㅗㅏ"), "봐")
        XCTAssertEqual(type("ㄷㅡㅣ"), "듸")
        XCTAssertEqual(type("ㄷㅗㅣㄷㅐ"), "되대")
        XCTAssertEqual(type("ㄷㅡㄹㅕㅆㅇㅓ"), "드렸어")
    }

    func testLoneJamo() {
        XCTAssertEqual(type("ㅋㅋㅋ"), "ㅋㅋㅋ")
        XCTAssertEqual(type("ㅠㅠ"), "ㅠㅠ")
        XCTAssertEqual(type("ㅏㄱ"), "ㅏㄱ")
    }

    func testNonFinalConsonants() {
        XCTAssertEqual(type("ㅇㅏㄸㅏ"), "아따")
    }

    func testBackspaceByJamo() {
        XCTAssertEqual(type("ㅂㅗㅏ", then: 1), "보")
        XCTAssertEqual(type("ㅇㅓㅂㅅ", then: 1), "업")
        XCTAssertEqual(type("ㅎㅏㄴ", then: 2), "ㅎ")
        XCTAssertEqual(type("ㅎㅏㄴ", then: 3), "")
        XCTAssertEqual(type("ㅎㅏㄴㄱㅡㄹ", then: 3), "한")
        // A committed syllable deletes whole, like Apple's keyboard.
        XCTAssertEqual(type("ㅎㅏㄴㄱㅡㄹ", then: 4), "")
    }

    func testOtherCharactersCommit() {
        XCTAssertEqual(type("ㅇㅡㅇ,"), "응,")
        XCTAssertEqual(type("ㅈㅏ."), "자.")
    }

    func testIncompleteFlag() {
        var c = HangulComposer()
        _ = c.input("ㄱ")
        XCTAssertTrue(c.isIncomplete)
        _ = c.input("ㅏ")
        XCTAssertFalse(c.isIncomplete)
        XCTAssertTrue(c.isComposing)
        XCTAssertEqual(c.commit(), "가")
        XCTAssertFalse(c.isComposing)
    }
}

final class TextDiffTests: XCTestCase {
    func testHighlightsCorrection() {
        let segments = TextDiff.segments(old: "응, 어제 선생님한테 책을 줬어.", new: "응, 어제 선생님께 책을 드렸어.")
        let changed = segments.filter(\.changed).map(\.text)
        XCTAssertEqual(changed, ["께", "드렸"])
        XCTAssertEqual(segments.map(\.text).joined(), "응, 어제 선생님께 책을 드렸어.")
    }

    func testIdentical() {
        XCTAssertEqual(TextDiff.changeCount(old: "好的", new: "好的"), 0)
    }
}

final class SettingsTests: XCTestCase {
    func testRoundTripAndProxyProfile() throws {
        var settings = KeyboardSettings()
        settings.updateContext(for: .korean) {
            $0.speechLevel = .hapsyo
            $0.speakingTo = " 선배 "
        }
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(KeyboardSettings.self, from: data)
        XCTAssertEqual(decoded, settings)
        let ko = decoded.proxyProfile(for: .korean)
        XCTAssertEqual(ko.speech_level, "hapsyo")
        XCTAssertEqual(ko.relationship, "선배")
        XCTAssertNil(ko.listener_gender) // not set: the check doesn't assume
        let zh = decoded.proxyProfile(for: .chinese)
        XCTAssertEqual(zh.region, "taiwan")
        XCTAssertNil(zh.relationship)
        XCTAssertNil(zh.speech_level)
    }

    func testOldSettingsMissingFieldsStillDecode() throws {
        let json = #"{"language":"zh","pauseSeconds":1.5,"profiles":{"ko":[]}}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(KeyboardSettings.self, from: json)
        XCTAssertEqual(decoded.language, .chinese)
        XCTAssertEqual(decoded.pauseSeconds, 1.5)
        XCTAssertEqual(decoded.model, KeyboardSettings().model)
    }

    func testRecentEmoji() {
        var s = KeyboardSettings()
        s.addRecentEmoji("😂"); s.addRecentEmoji("👍"); s.addRecentEmoji("😂")
        XCTAssertEqual(s.recentEmoji, ["😂", "👍"])
    }
}

final class LexiconTests: XCTestCase {
    func testKoreanCompletions() {
        let lexicon = KoreanLexicon(words: ["이", "안녕", "안녕하세요", "가방", "가족", "감사", "친구"])
        XCTAssertEqual(lexicon.completions(for: "안녀"), ["안녕", "안녕하세요"])
        XCTAssertEqual(lexicon.completions(for: "안녕"), ["안녕하세요"])
        XCTAssertEqual(lexicon.completions(for: "ㅊ"), ["친구"])
        // The final ㅂ of 갑 may start the next syllable: 가방.
        XCTAssertEqual(lexicon.completions(for: "갑"), ["가방"])
        XCTAssertEqual(lexicon.completions(for: "가"), ["가방", "가족", "감사"])
    }

    func testPinyinCandidates() {
        let lines: [Substring] = ["nihao\t你好\t你好", "ni\t你\t你", "hao\t好\t好", "ruanjian\t软件\t軟體", "nimen\t你们\t你們"]
        let lexicon = PinyinLexicon(lines: lines)
        let zh = lexicon.candidates(for: "nihao", script: .simplified)
        XCTAssertEqual(zh.first, .init(text: "你好", consumed: 5))
        XCTAssertTrue(zh.contains(.init(text: "你", consumed: 2)))
        XCTAssertEqual(lexicon.candidates(for: "ruanjian", script: .traditional).first?.text, "軟體")
        XCTAssertEqual(Array(lexicon.candidates(for: "ni", script: .traditional).map(\.text).prefix(3)), ["你", "你好", "你們"])
    }

    func testEmojiCatalog() {
        let catalog = EmojiCatalog(text: "Smileys & Emotion\t😀 😃\nFlags\t🏁")
        XCTAssertEqual(catalog.groups.map(\.emoji.count), [2, 1])
        XCTAssertEqual(catalog.groups.first?.symbol, "face.smiling")
    }
}
