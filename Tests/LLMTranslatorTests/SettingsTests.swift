import XCTest
@testable import LLMTranslatorCore

final class SettingsTests: XCTestCase {
    func testDefaults() {
        let settings = Settings()
        XCTAssertEqual(settings.method, .host)
        XCTAssertEqual(settings.nativeLanguage, "ru")
        XCTAssertEqual(settings.secondLanguage, "en")
        XCTAssertEqual(settings.host.baseURL, "http://127.0.0.1:1234/v1")
    }

    func testRoundTrip() throws {
        var settings = Settings()
        settings.host.model = "qwen"
        settings.secondLanguage = "de"
        let data = try JSONEncoder().encode(settings)
        XCTAssertEqual(try JSONDecoder().decode(Settings.self, from: data), settings)
    }

    func testMissingKeysFallBackToDefaults() throws {
        let data = Data(#"{"secondLanguage":"fr","host":{"model":"m"}}"#.utf8)
        let settings = Settings.decode(from: data)
        XCTAssertEqual(settings.secondLanguage, "fr")
        XCTAssertEqual(settings.host.model, "m")
        XCTAssertEqual(settings.host.prompt, Prompt.standard)
        XCTAssertEqual(settings.nativeLanguage, "ru")
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
        XCTAssertEqual(s.host.baseURL, "http://h:1/v1")
        XCTAssertEqual(s.host.model, "m")
        XCTAssertEqual(s.host.maxTokens, 4096)
        XCTAssertEqual(s.host.prompt, "P {to}")
        XCTAssertTrue(s.host.trimAnswer)
        XCTAssertEqual(s.secondLanguage, "de")
        XCTAssertFalse(s.joinBrokenLines)
        XCTAssertTrue(s.copyTranslation)
        XCTAssertEqual(s.developer.doubleCopyGapSeconds, 0.5)
        XCTAssertEqual(s.developer.popupMaxWidth, 800)
        XCTAssertEqual(s.developer.popupGrowth, 1.5)
        XCTAssertFalse(s.developer.streamLLM)
        XCTAssertFalse(s.developer.highlightIconWhileTranslating)
    }

    func testEarlierDefaultPromptsAreUpgraded() {
        for old in Prompt.earlierStandards {
            let stored = try! JSONSerialization.data(withJSONObject: ["host": ["prompt": old]])
            XCTAssertEqual(Settings.decode(from: stored).host.prompt, Prompt.standard)
        }
        let custom = try! JSONSerialization.data(withJSONObject: ["host": ["prompt": "Mine {to}"]])
        XCTAssertEqual(Settings.decode(from: custom).host.prompt, "Mine {to}")
    }

    func testMaxTokensArrowsMoveByPowersOfTwo() {
        XCTAssertEqual(HostSettings.nextMaxTokens(after: 8_192, up: true), 16_384)
        XCTAssertEqual(HostSettings.nextMaxTokens(after: 8_192, up: false), 4_096)
        XCTAssertEqual(HostSettings.nextMaxTokens(after: 6_000, up: true), 8_192)
        XCTAssertEqual(HostSettings.nextMaxTokens(after: 6_000, up: false), 4_096)
        XCTAssertEqual(HostSettings.nextMaxTokens(after: 256, up: false), 256)
        XCTAssertEqual(HostSettings.nextMaxTokens(after: 131_072, up: true), 131_072)
    }


}
