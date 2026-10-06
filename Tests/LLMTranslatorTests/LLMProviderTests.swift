import XCTest
@testable import LLMTranslatorCore

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
        host.prompt = "→{language1/language2}"
        XCTAssertEqual(provider(host).buildMessages(for: "Hi", from: "en", to: "de")[0]["content"], "→de")
        host.prompt = "old name {to}"
        XCTAssertEqual(provider(host).buildMessages(for: "Hi", from: "en", to: "de")[0]["content"], "old name de")
    }

    func testPromptWithoutPlaceholderIsFlagged() {
        var host = HostSettings()
        XCTAssertTrue(host.promptNamesLanguage)
        host.prompt = "Translate."
        XCTAssertFalse(host.promptNamesLanguage)
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
        let p = LLMProvider(host: HostSettings(), requestBody: AppConfig.default.requestBody, trimsWhitespace: true)
        let data = Data(#"{"choices":[{"message":{"role":"assistant","content":"  Привет\n"}}]}"#.utf8)
        XCTAssertEqual(try p.extractAnswer(from: data), "Привет")
    }
}
