import XCTest
@testable import LLMTranslatorCore

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
    /// Records what the pipeline asked for and answers with a fixed text.
    final class Recorder: TranslationProvider, @unchecked Sendable {
        var asked: (text: String, source: String?, target: String)?
        func translate(text: String, from source: String?, to target: String) async throws -> String {
            asked = (text, source, target)
            return "answer"
        }
    }

    func testJoinsLinesAndPicksDirection() async throws {
        let recorder = Recorder()
        let job = TranslationPipeline.start("Это предложение\nразорвано PDF", settings: Settings(), provider: recorder)
        XCTAssertEqual(job.text, "Это предложение разорвано PDF")
        XCTAssertEqual(job.source, "ru")
        XCTAssertEqual(job.target, "en")
        XCTAssertFalse(job.trimsAnswer)
        var pieces: [String] = []
        for try await piece in job.pieces { pieces.append(piece) }
        XCTAssertEqual(pieces, ["answer"])
        XCTAssertEqual(recorder.asked?.text, "Это предложение разорвано PDF")
        XCTAssertEqual(recorder.asked?.target, "en")
    }

    func testRespectsSettings() {
        var settings = Settings()
        settings.joinBrokenLines = false
        settings.language2 = "de"
        settings.localLLM.trimAnswer = true
        let job = TranslationPipeline.start("Hello\nworld", settings: settings, provider: Recorder())
        XCTAssertEqual(job.text, "Hello\nworld")
        XCTAssertNil(job.source)
        XCTAssertEqual(job.target, "ru")
        XCTAssertTrue(job.trimsAnswer)
        XCTAssertEqual(TranslationPipeline.start("Привет", settings: settings, provider: Recorder()).target, "de")
    }

    func testOnlyTheLLMTrimsItsAnswer() {
        var settings = Settings()
        settings.localLLM.trimAnswer = true
        settings.method = .appleTranslation
        XCTAssertFalse(TranslationPipeline.start("Hi", settings: settings, provider: Recorder()).trimsAnswer)
    }

    func testErrorsReachTheCaller() async {
        let provider = LocalLLMProvider(settings: { var s = LocalLLMSettings(); s.baseURL = "http://127.0.0.1:9/v1"; return s }())
        do {
            for try await _ in TranslationPipeline.start("Hi", settings: Settings(), provider: provider).pieces {}
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? OpenAIClientError, .unreachable("http://127.0.0.1:9/v1"))
        }
    }

    func testMethodsSurviveStorage() {
        var settings = Settings()
        settings.method = .appleTranslation
        let data = try! JSONEncoder().encode(settings)
        XCTAssertEqual(Settings.decode(from: data).method, .appleTranslation)
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains(#""method":"apple""#))
    }
}
