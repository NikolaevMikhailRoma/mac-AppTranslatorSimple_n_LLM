import XCTest
@testable import LLMTranslatorCore

/// The settings.json shipped in Resources, so the tests break if it stops decoding.
private func shippedConfig() throws -> AppConfig {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Resources/settings.json")
    return try JSONDecoder().decode(AppConfig.self, from: Data(contentsOf: url))
}

final class AppConfigTests: XCTestCase {
    func testShippedSettingsDecode() throws {
        let config = try shippedConfig()
        XCTAssertEqual(config.languageCodes, ["ru", "en"])
        XCTAssertEqual(config.baseURL, "http://127.0.0.1:1234/v1/chat/completions")
        XCTAssertNil(config.apiKey)
        XCTAssertEqual(config.requestBody.stream, false)
    }

    func testRequestBodyOmitsUnsetOptionals() {
        let body = RequestBody(temperature: 0, max_tokens: 10, stream: false, tool_choice: nil, enable_thinking: nil)
        XCTAssertEqual(Set(body.toDictionary().keys), ["temperature", "max_tokens", "stream"])
    }
}

final class LanguageDetectorTests: XCTestCase {
    func testCyrillicTranslatesToEnglish() throws {
        let detector = LanguageDetector(config: try shippedConfig())
        let (source, target) = detector.determineLanguageDirection(for: "Привет, мир")
        XCTAssertEqual(source, "ru")
        XCTAssertEqual(target, "en")
    }

    func testLatinTranslatesToRussian() throws {
        let detector = LanguageDetector(config: try shippedConfig())
        let (source, target) = detector.determineLanguageDirection(for: "Hello, world")
        XCTAssertEqual(source, "en")
        XCTAssertEqual(target, "ru")
    }

    func testMixedTextFollowsMajority() throws {
        let detector = LanguageDetector(config: try shippedConfig())
        XCTAssertEqual(detector.determineLanguageDirection(for: "Запусти swift build ещё раз").source, "ru")
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
    func testPayloadCarriesBodyAndMessages() throws {
        let provider = LLMProvider(config: try shippedConfig())
        let messages = provider.buildMessages(for: "Hi", from: "en", to: "ru")
        let data = try provider.makeRequestPayload(messages: messages)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(json["temperature"] as? Double, 0)
        XCTAssertEqual(json["enable_thinking"] as? Bool, false)
        XCTAssertNil(json["model"], "modelIdentifier is null, so the server's default model is used")
        let sent = try XCTUnwrap(json["messages"] as? [[String: String]])
        XCTAssertEqual(sent.map { $0["role"] }, ["system", "user"])
        XCTAssertEqual(sent[1]["content"], "Hi")
        XCTAssertTrue(sent[0]["content"]!.contains("Translate from en to ru"))
    }

    func testExtractAnswerTrimsWhitespace() throws {
        let provider = LLMProvider(config: try shippedConfig())
        let data = Data(#"{"choices":[{"message":{"role":"assistant","content":"  Привет\n"}}]}"#.utf8)
        XCTAssertEqual(try provider.extractAnswer(from: data), "Привет")
    }
}
