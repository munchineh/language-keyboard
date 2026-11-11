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
        settings.updateActiveProfile(for: .korean) { $0.speechLevel = .hapsyo }
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(KeyboardSettings.self, from: data)
        XCTAssertEqual(decoded, settings)
        XCTAssertEqual(decoded.proxyProfile(for: .korean).speech_level, "hapsyo")
        XCTAssertEqual(decoded.proxyProfile(for: .chinese).region, "taiwan")
        XCTAssertNil(decoded.proxyProfile(for: .chinese).speech_level)
    }

    func testOldSettingsMissingFieldsStillDecode() throws {
        let json = #"{"language":"zh","pauseSeconds":1.5}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(KeyboardSettings.self, from: json)
        XCTAssertEqual(decoded.language, .chinese)
        XCTAssertEqual(decoded.pauseSeconds, 1.5)
        XCTAssertEqual(decoded.model, KeyboardSettings().model)
    }
}
