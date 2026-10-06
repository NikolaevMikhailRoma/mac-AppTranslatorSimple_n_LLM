import XCTest
@testable import LLMTranslatorCore

final class SettingsTests: XCTestCase {
    func testDefaults() {
        let settings = Settings()
        XCTAssertEqual(settings.method, .localLLM)
        XCTAssertEqual(settings.language1, "ru")
        XCTAssertEqual(settings.language2, "en")
        XCTAssertEqual(settings.localLLM.baseURL, "http://127.0.0.1:1234/v1")
    }

    func testRoundTrip() throws {
        var settings = Settings()
        settings.localLLM.model = "qwen"
        settings.language2 = "de"
        let data = try JSONEncoder().encode(settings)
        XCTAssertEqual(try JSONDecoder().decode(Settings.self, from: data), settings)
    }

    func testMissingKeysFallBackToDefaults() throws {
        let data = Data(#"{"secondLanguage":"fr","host":{"model":"m"}}"#.utf8)
        let settings = Settings.decode(from: data)
        XCTAssertEqual(settings.language2, "fr")
        XCTAssertEqual(settings.localLLM.model, "m")
        XCTAssertEqual(settings.localLLM.prompt, Prompt.standard)
        XCTAssertEqual(settings.language1, "ru")
        XCTAssertEqual(settings.developer, DeveloperSettings())
    }

    func testUnreadableDataGivesDefaults() {
        XCTAssertEqual(Settings.decode(from: Data("not json".utf8)), Settings())
        XCTAssertEqual(Settings.decode(from: Data(#"{"method":"no-such-method"}"#.utf8)), Settings())
    }

    /// Settings saved by 0.0.4 before the refactoring must read back unchanged.
    func testSettingsSavedBeforeRefactoringReadBack() {
        let saved = #"{"method":"host","host":{"baseURL":"http://h:1/v1","model":"m","maxTokens":4096,"prompt":"P {to}","trimAnswer":true},"nativeLanguage":"ru","secondLanguage":"de","joinBrokenLines":false,"copyTranslation":true,"developer":{"doubleCopyGapSeconds":0.5,"popupMaxWidth":800,"popupGrowth":1.5,"streamLLM":false,"highlightIconWhileTranslating":false}}"#
        let s = Settings.decode(from: Data(saved.utf8))
        XCTAssertEqual(s.localLLM.baseURL, "http://h:1/v1")
        XCTAssertEqual(s.localLLM.model, "m")
        XCTAssertEqual(s.localLLM.maxTokens, 4096)
        XCTAssertEqual(s.localLLM.prompt, "P {to}")
        XCTAssertTrue(s.localLLM.trimAnswer)
        XCTAssertEqual(s.language2, "de")
        XCTAssertFalse(s.joinBrokenLines)
        XCTAssertTrue(s.copyTranslation)
        XCTAssertEqual(s.developer.doubleCopyGapSeconds, 0.5)
        XCTAssertEqual(s.developer.popupMaxWidth, 800)
        XCTAssertEqual(s.developer.popupGrowth, 1.5)
        XCTAssertFalse(s.developer.streamLLM)
        XCTAssertFalse(s.developer.highlightIconWhileTranslating)
    }

    /// Settings saved by an early 0.0.4 build, with keys that no longer exist.
    func testEarlyBuildSettingsReadBack() {
        let saved = #"{"method":"host","developer":{"maxLineLength":160,"highlightIconWhileTranslating":true,"doubleCopyGapSeconds":0.3},"host":{"baseURL":"http://127.0.0.1:1234/v1","maxTokens":9000,"prompt":"Translate to {to}.\nPreserve every character of formatting: spaces, newlines, tabs, punctuation, emojis, special symbols.\nOutput ONLY the translation, nothing else.","model":""},"secondLanguage":"en","trimTranslation":true,"nativeLanguage":"ru"}"#
        let s = Settings.decode(from: Data(saved.utf8))
        XCTAssertEqual(s.method, .localLLM)
        XCTAssertEqual(s.localLLM.maxTokens, 9_000, "a typed value is kept")
        XCTAssertEqual(s.localLLM.prompt, Prompt.standard, "the old standard prompt is upgraded")
        XCTAssertEqual(s.developer.popupMaxWidth, 640, "a setting added later gets its default")
        XCTAssertTrue(s.developer.streamLLM)
    }

    func testEarlierDefaultPromptsAreUpgraded() {
        for old in Prompt.earlierStandards {
            let stored = try! JSONSerialization.data(withJSONObject: ["host": ["prompt": old]])
            XCTAssertEqual(Settings.decode(from: stored).localLLM.prompt, Prompt.standard)
        }
        let custom = try! JSONSerialization.data(withJSONObject: ["host": ["prompt": "Mine {to}"]])
        XCTAssertEqual(Settings.decode(from: custom).localLLM.prompt, "Mine {to}")
    }

    func testMaxTokensArrowsMoveByPowersOfTwo() {
        XCTAssertEqual(LocalLLMSettings.nextMaxTokens(after: 8_192, up: true), 16_384)
        XCTAssertEqual(LocalLLMSettings.nextMaxTokens(after: 8_192, up: false), 4_096)
        XCTAssertEqual(LocalLLMSettings.nextMaxTokens(after: 6_000, up: true), 8_192)
        XCTAssertEqual(LocalLLMSettings.nextMaxTokens(after: 6_000, up: false), 4_096)
        XCTAssertEqual(LocalLLMSettings.nextMaxTokens(after: 256, up: false), 256)
        XCTAssertEqual(LocalLLMSettings.nextMaxTokens(after: 131_072, up: true), 131_072)
    }


}
