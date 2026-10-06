import XCTest
@testable import LLMTranslatorCore

final class LocalLLMProviderTests: XCTestCase {
    func testStandardPrompt() {
        let messages = LocalLLMProvider(settings: LocalLLMSettings()).messages(for: "Hi", to: "ru")
        XCTAssertEqual(messages[0]["content"], """
            Translate to ru.
            Preserve every character of formatting: spaces, newlines, tabs, punctuation, emojis, special symbols.
            Output ONLY the translation, nothing else.
            """)
        XCTAssertEqual(messages[1], ["role": "user", "content": "Hi"])
    }

    func testBodyUsesSettings() throws {
        var settings = LocalLLMSettings()
        settings.model = "m"
        settings.maxTokens = 4_096
        let data = try LocalLLMProvider(settings: settings).body(for: "Hi", to: "de", stream: false)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["model"] as? String, "m")
        XCTAssertEqual(json["max_tokens"] as? Int, 4_096)
        XCTAssertEqual(json["stream"] as? Bool, false)
    }
}

final class PromptTests: XCTestCase {
    func testPlaceholderAndOldName() {
        XCTAssertEqual(Prompt.render("→{language1/language2}", target: "de"), "→de")
        XCTAssertEqual(Prompt.render("old name {to}", target: "de"), "old name de")
    }

    func testPromptWithoutPlaceholderIsFlagged() {
        XCTAssertTrue(Prompt.namesLanguage(Prompt.standard))
        XCTAssertTrue(Prompt.namesLanguage("Mine {to}"))
        XCTAssertFalse(Prompt.namesLanguage("Translate."))
    }
}
