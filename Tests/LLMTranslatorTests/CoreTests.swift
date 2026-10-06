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

final class ModelListTests: XCTestCase {
    func testDecodesLMStudioAnswer() throws {
        let data = Data(#"{"data":[{"id":"qwen/qwen3.5-9b","object":"model"},{"id":"gemma-3"}],"object":"list"}"#.utf8)
        XCTAssertEqual(try ModelList.decode(data), ["qwen/qwen3.5-9b", "gemma-3"])
    }

    func testModelsURL() {
        XCTAssertEqual(HostSettings().modelsURL?.absoluteString, "http://127.0.0.1:1234/v1/models")
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

final class StreamingTests: XCTestCase {
    func testParsesLMStudioChunks() {
        XCTAssertEqual(LLMProvider.parseEvent(#"data: {"choices":[{"index":0,"delta":{"role":"assistant","content":"При"}}]}"#),
                       .piece("При"))
        XCTAssertEqual(LLMProvider.parseEvent(#"data: {"choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}"#), .skip)
        XCTAssertEqual(LLMProvider.parseEvent("data: [DONE]"), .done)
        XCTAssertEqual(LLMProvider.parseEvent(""), .skip)
        XCTAssertEqual(LLMProvider.parseEvent(": keep-alive"), .skip)
    }

    func testStreamingPayloadAsksForStream() throws {
        let p = LLMProvider(host: HostSettings(), requestBody: AppConfig.default.requestBody)
        let json = try JSONSerialization.jsonObject(with: p.makeRequestPayload(messages: [], stream: true)) as? [String: Any]
        XCTAssertEqual(json?["stream"] as? Bool, true)
    }

    /// A method that cannot stream still works through translateStream: one piece.
    func testDefaultStreamYieldsWholeTranslation() async throws {
        final class Fixed: TranslationProvider {
            func translate(text: String, from: String, to: String) async throws -> String { "whole" }
        }
        var pieces: [String] = []
        for try await piece in Fixed().translateStream(text: "x", from: "ru", to: "en") { pieces.append(piece) }
        XCTAssertEqual(pieces, ["whole"])
    }
}

final class LineJoinerTests: XCTestCase {
    func testJoinsLinesInsideAParagraph() {
        XCTAssertEqual(LineJoiner.join("Это предложение\nразорвано посередине\nвёрсткой PDF."),
                       "Это предложение разорвано посередине вёрсткой PDF.")
    }

    func testKeepsParagraphs() {
        XCTAssertEqual(LineJoiner.join("First line\nstill first.\n\n\n\nSecond\nparagraph."),
                       "First line still first.\n\nSecond paragraph.")
    }

    func testGluesHyphenatedWord() {
        XCTAssertEqual(LineJoiner.join("экс-\nпорт данных"), "экспорт данных")
        XCTAssertEqual(LineJoiner.join("well-\nknown"), "wellknown")
    }

    func testKeepsHyphenBeforeCapital() {
        XCTAssertEqual(LineJoiner.join("Нью-\nЙорк"), "Нью-Йорк")
    }

    func testKeepsListItems() {
        XCTAssertEqual(LineJoiner.join("Шаги:\n- первый\n- второй\n1. третий\n2) четвёртый"),
                       "Шаги:\n- первый\n- второй\n1. третий\n2) четвёртый")
    }

    func testNormalizesWindowsNewlinesAndSpaces() {
        XCTAssertEqual(LineJoiner.join("  one  \r\n  two  "), "one two")
    }

    func testSingleLineUnchanged() {
        XCTAssertEqual(LineJoiner.join("Привет, мир"), "Привет, мир")
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
        XCTAssertEqual(json["max_tokens"] as? Int, 8_192)
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
