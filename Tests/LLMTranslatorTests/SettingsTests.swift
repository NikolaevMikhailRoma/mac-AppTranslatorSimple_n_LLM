import XCTest
@testable import LLMTranslatorCore

final class SettingsTests: XCTestCase {
    func testDefaults() {
        let settings = Settings()
        XCTAssertEqual(settings.method, .host)
        XCTAssertEqual(settings.nativeLanguage, "ru")
        XCTAssertEqual(settings.secondLanguage, "en")
        XCTAssertEqual(settings.host.chatCompletionsURL?.absoluteString, "http://127.0.0.1:1234/v1/chat/completions")
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
        let settings = try JSONDecoder().decode(Settings.self, from: data)
        XCTAssertEqual(settings.secondLanguage, "fr")
        XCTAssertEqual(settings.host.model, "m")
        XCTAssertEqual(settings.host.prompt, HostSettings.defaultPrompt)
        XCTAssertEqual(settings.nativeLanguage, "ru")
    }

    func testEarlierDefaultPromptsAreUpgraded() throws {
        for old in HostSettings.previousDefaultPrompts {
            let stored = try JSONEncoder().encode(["prompt": old])
            XCTAssertEqual(try JSONDecoder().decode(HostSettings.self, from: stored).prompt, HostSettings.defaultPrompt)
        }
        let custom = try JSONEncoder().encode(["prompt": "Mine {to}"])
        XCTAssertEqual(try JSONDecoder().decode(HostSettings.self, from: custom).prompt, "Mine {to}")
    }

    func testMaxTokensArrowsMoveByPowersOfTwo() {
        XCTAssertEqual(HostSettings.nextMaxTokens(after: 8_192, up: true), 16_384)
        XCTAssertEqual(HostSettings.nextMaxTokens(after: 8_192, up: false), 4_096)
        XCTAssertEqual(HostSettings.nextMaxTokens(after: 6_000, up: true), 8_192)
        XCTAssertEqual(HostSettings.nextMaxTokens(after: 6_000, up: false), 4_096)
        XCTAssertEqual(HostSettings.nextMaxTokens(after: 256, up: false), 256)
        XCTAssertEqual(HostSettings.nextMaxTokens(after: 131_072, up: true), 131_072)
    }

    func testTrailingSlashInServerURL() {
        var host = HostSettings()
        host.baseURL = " http://localhost:11434/v1/ "
        XCTAssertEqual(host.chatCompletionsURL?.absoluteString, "http://localhost:11434/v1/chat/completions")
    }

    func testRequestBodyOmitsUnsetOptionals() {
        let body = RequestBody(temperature: 0, max_tokens: 10, stream: false, tool_choice: nil, enable_thinking: nil)
        XCTAssertEqual(Set(body.toDictionary().keys), ["temperature", "max_tokens", "stream"])
    }
}
