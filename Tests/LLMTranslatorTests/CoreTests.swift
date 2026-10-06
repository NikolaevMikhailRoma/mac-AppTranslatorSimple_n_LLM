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

    func testDraftDefaultPromptIsUpgraded() throws {
        let stored = try JSONEncoder().encode(["prompt": HostSettings.previousDefaultPrompt])
        XCTAssertEqual(try JSONDecoder().decode(HostSettings.self, from: stored).prompt, HostSettings.defaultPrompt)
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

final class LanguageDetectorTests: XCTestCase {
    private let detector = LanguageDetector(native: "ru", second: "en")

    func testCyrillicTranslatesToLanguage2() {
        XCTAssertEqual(detector.determineLanguageDirection(for: "Привет, мир").target, "en")
    }

    func testLatinTranslatesToLanguage1() {
        XCTAssertEqual(detector.determineLanguageDirection(for: "Hello, world").target, "ru")
    }

    func testAnyNonCyrillicScriptTranslatesToLanguage1() {
        XCTAssertEqual(detector.determineLanguageDirection(for: "你好，世界").target, "ru")
    }

    func testMixedTextFollowsMajority() {
        XCTAssertEqual(detector.determineLanguageDirection(for: "Запусти swift build ещё раз").target, "en")
    }

    func testNoLettersGoesToLanguage2() {
        XCTAssertEqual(detector.determineLanguageDirection(for: "12345").target, "en")
    }

    func testLanguage2IsTheSetting() {
        let german = LanguageDetector(native: "ru", second: "de")
        XCTAssertEqual(german.determineLanguageDirection(for: "Привет").target, "de")
    }
}

final class TextWrapTests: XCTestCase {
    func testNilOrZeroLeavesTextAlone() {
        XCTAssertEqual(TextWrap.wrap("a b c", maxLength: nil), "a b c")
        XCTAssertEqual(TextWrap.wrap("a b c", maxLength: 0), "a b c")
    }

    func testBreaksAtWordBoundary() {
        XCTAssertEqual(TextWrap.wrap("aaa bbb ccc", maxLength: 7), "aaa bbb\nccc")
    }

    func testKeepsExistingNewlines() {
        XCTAssertEqual(TextWrap.wrap("one\n\ntwo", maxLength: 3), "one\n\ntwo")
    }
}

final class LLMProviderTests: XCTestCase {
    private func provider(_ host: HostSettings = HostSettings()) -> LLMProvider {
        LLMProvider(host: host, requestBody: AppConfig.default.requestBody)
    }

    func testDefaultPromptIsUnchanged() {
        let messages = provider().buildMessages(for: "Hi", from: "en", to: "ru")
        XCTAssertEqual(messages[0]["content"], """
            Translate to ru.
            Preserve every character of formatting: spaces, newlines, tabs, punctuation, emojis, special symbols.
            Output ONLY the translation, nothing else.
            """)
    }

    func testCustomPromptGetsCodes() {
        var host = HostSettings()
        host.prompt = "→{to}"
        XCTAssertEqual(provider(host).buildMessages(for: "Hi", from: "en", to: "de")[0]["content"], "→de")
    }

    func testPayloadCarriesBodyAndMessages() throws {
        let p = provider()
        let data = try p.makeRequestPayload(messages: p.buildMessages(for: "Hi", from: "en", to: "ru"))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(json["temperature"] as? Double, 0)
        XCTAssertNil(json["enable_thinking"], "not sent: Qwen does not honour it reliably")
        XCTAssertEqual(json["max_tokens"] as? Int, 10_000)
        XCTAssertNil(json["model"], "an empty model means the one loaded on the server")
        let sent = try XCTUnwrap(json["messages"] as? [[String: String]])
        XCTAssertEqual(sent.map { $0["role"] }, ["system", "user"])
        XCTAssertEqual(sent[1]["content"], "Hi")
    }

    func testModelIsSentWhenSet() throws {
        var host = HostSettings()
        host.model = " qwen/qwen3.5-9b "
        let p = provider(host)
        let json = try JSONSerialization.jsonObject(with: p.makeRequestPayload(messages: [])) as? [String: Any]
        XCTAssertEqual(json?["model"] as? String, "qwen/qwen3.5-9b")
    }

    func testExtractAnswerKeepsWhitespaceWhenAsked() throws {
        let p = LLMProvider(host: HostSettings(), requestBody: AppConfig.default.requestBody, trimsWhitespace: false)
        let data = Data(#"{"choices":[{"message":{"role":"assistant","content":"  Привет\n"}}]}"#.utf8)
        XCTAssertEqual(try p.extractAnswer(from: data), "  Привет\n")
    }

    func testExtractAnswerTrimsWhitespace() throws {
        let data = Data(#"{"choices":[{"message":{"role":"assistant","content":"  Привет\n"}}]}"#.utf8)
        XCTAssertEqual(try provider().extractAnswer(from: data), "Привет")
    }
}
