import XCTest
@testable import TranslatorCore

/// Offline: building the request and reading the answer.
final class DeepLProviderTests: XCTestCase {
    /// Nothing listens on port 9: a test that gets past the checks fails with `unreachable`.
    let offline = DeepLProvider(endpoint: URL(string: "http://127.0.0.1:9/v1/translate")!)

    func testRequest() throws {
        let request = try DeepLProvider().request("Tom & Jerry\n\"Да\"", from: "ru", to: "en")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url, DeepLProvider.endpoint)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "None")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
        XCTAssertEqual(body["text"] as? [String], ["Tom & Jerry\n\"Да\""])
        XCTAssertEqual(body["source_lang"] as? String, "ru")
        XCTAssertEqual(body["target_lang"] as? String, "en-US")
    }

    func testTargetCodes() {
        XCTAssertEqual(DeepLProvider.targetCode("en"), "en-US")
        XCTAssertEqual(DeepLProvider.targetCode("ru"), "ru", "lower case: \"RU\" comes back untranslated")
    }

    /// A real answer, en → ru (2026-10-11, the research for this method).
    func testDecodesAnswer() throws {
        let data = Data(#"{"translations":[{"detected_source_language":"en","text":"Здравствуйте, это простой тест.","is_language_detection_confident":false}]}"#.utf8)
        XCTAssertEqual(try DeepLProvider.decode(data), "Здравствуйте, это простой тест.")
    }

    func testUnexpectedAnswerIsAnError() {
        for body in ["<html>Too many requests</html>", "{}", #"{"translations":[]}"#] {
            XCTAssertThrowsError(try DeepLProvider.decode(Data(body.utf8)), body) {
                XCTAssertEqual($0 as? DeepLError, .unreadable)
            }
        }
    }

    func testNeedsTheSource() async {
        await assertFails(offline, "Hi", from: nil, with: .noSource)
    }

    /// Refused before any request: DeepL would answer HTTP 400.
    func testTooLongTextIsNotSent() async {
        await assertFails(offline, String(repeating: "a", count: DeepLProvider.maxLength + 1), from: "en", with: .tooLong)
        // Counted as DeepL counts: an emoji is two UTF-16 units.
        await assertFails(offline, String(repeating: "😀", count: DeepLProvider.maxLength / 2 + 1), from: "en", with: .tooLong)
    }

    func testLimitItselfIsSent() async {
        await assertFails(offline, String(repeating: "a", count: DeepLProvider.maxLength), from: "en", with: .unreachable)
    }

    func testBlankTextIsNotSent() async throws {
        let answer = try await offline.translate(text: " \n", from: "en", to: "ru")
        XCTAssertEqual(answer, " \n")
    }

    func testNoConnectionIsReadable() async {
        await assertFails(offline, "Hi", from: "en", with: .unreachable)
        XCTAssertEqual(DeepLError.unreachable.localizedDescription, "No answer from DeepL. Is the Mac online?")
    }

    private func assertFails(_ provider: DeepLProvider, _ text: String, from source: String?, with expected: DeepLError,
                             file: StaticString = #filePath, line: UInt = #line) async {
        do {
            _ = try await provider.translate(text: text, from: source, to: "ru")
            XCTFail("expected an error", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? DeepLError, expected, file: file, line: line)
        }
    }
}

/// Live: real requests to DeepL. Off by default, so that `swift test` stays offline; few requests,
/// the endpoint refuses many in a row: `DEEPL_LIVE=1 swift test --filter DeepLLiveTests`.
final class DeepLLiveTests: XCTestCase {
    let deepL = DeepLProvider()

    override func setUp() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["DEEPL_LIVE"] == "1", "set DEEPL_LIVE=1 to call DeepL")
    }

    /// Exact answers: the endpoint can send the text back untranslated with HTTP 200.
    func testEnglishToRussian() async throws {
        let answer = try await deepL.translate(text: "Good morning. The cat sleeps.", from: "en", to: "ru")
        XCTAssertEqual(answer, "Доброе утро. Кошка спит.")
    }

    func testRussianToEnglish() async throws {
        let answer = try await deepL.translate(text: "Привет, как дела?", from: "ru", to: "en")
        print("DeepL ru→en:", answer.debugDescription)
        XCTAssertTrue(answer.lowercased().contains("how are you"), answer)
    }

    func testKeepsNewlines() async throws {
        let answer = try await deepL.translate(text: "First paragraph.\n\nSecond paragraph.", from: "en", to: "ru")
        print("DeepL newlines:", answer.debugDescription)
        XCTAssertTrue(answer.contains("\n\n"), answer)
        XCTAssertFalse(answer.contains("paragraph"), answer)
    }

    /// The whole path, as after ⌘C C.
    func testThroughThePipeline() async throws {
        var settings = Settings()
        settings.method = .deepL
        let job = TranslationPipeline.start("Спасибо", settings: settings, provider: deepL)
        XCTAssertEqual(job.source, "ru")
        var answer = ""
        for try await piece in job.pieces { answer += piece }
        print("DeepL pipeline:", answer.debugDescription)
        XCTAssertTrue(answer.lowercased().contains("thank"), answer)
    }
}
