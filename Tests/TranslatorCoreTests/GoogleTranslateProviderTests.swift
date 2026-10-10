import XCTest
@testable import TranslatorCore

/// Offline: building the request and reading the answer.
final class GoogleTranslateProviderTests: XCTestCase {
    /// A real answer for "Hello world. How are you?\n\nSecond paragraph here.", en → ru (2026-10-11).
    let answer = #"[[["Привет, мир. ","Hello world. ",null,null,10],["Как вы?\n\n","How are you?\n\n",null,null,10,null,null,null,[[null,true]]],["Второй абзац здесь.","Second paragraph here.",null,null,3,null,null,[[]],[[["8e6adaf1f9ae06bcb9663531e5521abb","en_ru_2023q1.md"]]]]],null,"en",null,null,null,1,[],[["en"],null,[1],["en"]]]"#

    func testJoinsEverySentence() throws {
        XCTAssertEqual(try GoogleTranslateProvider.decode(Data(answer.utf8)), "Привет, мир. Как вы?\n\nВторой абзац здесь.")
    }

    func testSkipsSentencesWithoutTranslation() throws {
        let data = Data(#"[[["Да. ","Yes. ",null],[null,null,"Da"],["Нет.","No."]],null,"en"]"#.utf8)
        XCTAssertEqual(try GoogleTranslateProvider.decode(data), "Да. Нет.")
    }

    /// What Google sends for an empty or all-spaces text.
    func testEmptyTextGivesEmptyTranslation() throws {
        let data = Data(#"[[["","",null,null,5]],null,"en",null,null,null,0,[],[["en"],null,[0],["en"]]]"#.utf8)
        XCTAssertEqual(try GoogleTranslateProvider.decode(data), "")
    }

    func testUnexpectedAnswerIsAnError() {
        for body in ["<html>Our systems have detected unusual traffic</html>", "{}", "[]", #"{"error":"x"}"#] {
            XCTAssertThrowsError(try GoogleTranslateProvider.decode(Data(body.utf8)), body) {
                XCTAssertEqual($0 as? GoogleTranslateError, .unreadable)
            }
        }
    }

    func testRequest() throws {
        let request = GoogleTranslateProvider().request("Tom & Jerry + 1 = 2?\nДа", from: "en", to: "ru")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString,
                       "https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=ru&dt=t")
        let body = String(decoding: try XCTUnwrap(request.httpBody), as: UTF8.self)
        XCTAssertEqual(body, "q=Tom%20%26%20Jerry%20%2B%201%20%3D%202%3F%0A%D0%94%D0%B0")
        XCTAssertEqual(String(body.dropFirst(2)).removingPercentEncoding, "Tom & Jerry + 1 = 2?\nДа")
    }

    func testNeedsTheSource() async {
        do {
            _ = try await GoogleTranslateProvider().translate(text: "Hi", from: nil, to: "ru")
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? GoogleTranslateError, .noSource)
        }
    }

    func testNoConnectionIsReadable() async {
        let provider = GoogleTranslateProvider(endpoint: URL(string: "http://127.0.0.1:9/translate_a/single")!)    // nothing listens on port 9
        do {
            _ = try await provider.translate(text: "Hi", from: "en", to: "ru")
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error.localizedDescription, "No answer from Google Translate. Is the Mac online?")
        }
    }
}

/// Live: real requests to Google. Off by default, so that `swift test` stays offline:
/// `GOOGLE_LIVE=1 swift test --filter GoogleTranslateLiveTests`.
final class GoogleTranslateLiveTests: XCTestCase {
    let google = GoogleTranslateProvider()

    override func setUp() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["GOOGLE_LIVE"] == "1", "set GOOGLE_LIVE=1 to call Google")
    }

    func testEnglishToRussian() async throws {
        let answer = try await google.translate(text: "Hello world.", from: "en", to: "ru")
        XCTAssertEqual(answer, "Привет, мир.")
    }

    func testRussianToEnglish() async throws {
        let answer = try await google.translate(text: "Привет, как дела?", from: "ru", to: "en")
        XCTAssertEqual(answer, "Hi, how are you?")
    }

    /// Every sentence is in the answer, not only the first one.
    func testSeveralSentences() async throws {
        let answer = try await google.translate(text: "The cat sleeps. The dog barks. The bird sings.", from: "en", to: "ru")
        XCTAssertEqual(answer.components(separatedBy: ".").count - 1, 3, answer)
        XCTAssertFalse(answer.contains("The "), answer)
    }

    func testKeepsNewlines() async throws {
        let answer = try await google.translate(text: "First paragraph.\n\nSecond paragraph.\nThird line.", from: "en", to: "ru")
        XCTAssertTrue(answer.contains("\n\n"), answer)
        XCTAssertEqual(answer.components(separatedBy: "\n").count, 4, answer)
    }

    /// `&`, `+`, `=` would cut or change the text if the body were not encoded. Google itself turns `&` into «и».
    func testSpecialCharactersReachGoogle() async throws {
        let answer = try await google.translate(text: "Salt & pepper + 2 = good", from: "en", to: "ru")
        XCTAssertEqual(answer, "Соль и перец + 2 = хорошо")
    }

    /// Far over what Google takes in the URL (HTTP 400 at about 20 000 characters).
    func testLongText() async throws {
        let text = String(repeating: "This is one sentence of a long text. ", count: 600)
        XCTAssertGreaterThan(text.count, 20_000)
        let answer = try await google.translate(text: text, from: "en", to: "ru")
        XCTAssertGreaterThan(answer.count, text.count / 2)
        XCTAssertFalse(answer.contains("This is"), "every sentence translated")
    }

    /// The whole path, as after ⌘C C.
    func testThroughThePipeline() async throws {
        var settings = Settings()
        settings.method = .google
        let job = TranslationPipeline.start("Good morning", settings: settings, provider: google)
        XCTAssertEqual(job.source, "en")
        var answer = ""
        for try await piece in job.pieces { answer += piece }
        XCTAssertEqual(answer, "Доброе утро")
    }
}
