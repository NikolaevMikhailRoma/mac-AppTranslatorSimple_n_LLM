import XCTest
@testable import TranslatorCore

final class StreamedTextTests: XCTestCase {
    func testKeepsEverythingByDefault() {
        var text = StreamedText(trims: false)
        ["\n ", "При", "вет", " \n"].forEach { text.append($0) }
        text.finish()
        XCTAssertEqual(text.text, "\n Привет \n")
    }

    func testTrimsLeadingAsItComesAndTrailingAtTheEnd() {
        var text = StreamedText(trims: true)
        text.append("\n ")
        XCTAssertEqual(text.text, "", "nothing to show before the first word")
        ["При", "вет", " \n"].forEach { text.append($0) }
        XCTAssertEqual(text.text, "Привет \n")
        text.finish()
        XCTAssertEqual(text.text, "Привет")
    }
}

final class TranslationPipelineTests: XCTestCase {
    /// Nothing listens on port 9, so no request reaches a real model.
    private func settings() -> Settings {
        var settings = Settings()
        settings.localLLM.baseURL = "http://127.0.0.1:9/v1"
        return settings
    }

    func testJoinsLinesAndPicksDirection() {
        let job = TranslationPipeline.start("Это предложение\nразорвано PDF", settings: settings())
        XCTAssertEqual(job.text, "Это предложение разорвано PDF")
        XCTAssertEqual(job.source, "ru")
        XCTAssertEqual(job.target, "en")
        XCTAssertFalse(job.trimsAnswer)
    }

    func testRespectsSettings() {
        var settings = settings()
        settings.joinBrokenLines = false
        settings.language2 = "de"
        settings.localLLM.trimAnswer = true
        let job = TranslationPipeline.start("Hello\nworld", settings: settings)
        XCTAssertEqual(job.text, "Hello\nworld")
        XCTAssertEqual(job.target, "ru")
        XCTAssertTrue(job.trimsAnswer)
        XCTAssertEqual(TranslationPipeline.start("Привет", settings: settings).target, "de")
    }

    func testErrorsReachTheCaller() async {
        do {
            for try await _ in TranslationPipeline.start("Hi", settings: settings()).pieces {}
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? OpenAIClientError, .unreachable("http://127.0.0.1:9/v1"))
        }
    }
}
