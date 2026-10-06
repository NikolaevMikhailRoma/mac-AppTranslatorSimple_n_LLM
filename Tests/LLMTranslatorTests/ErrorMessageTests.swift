import XCTest
@testable import LLMTranslatorCore

final class ErrorMessageTests: XCTestCase {
    func testServerDownIsReadable() async {
        var host = HostSettings()
        host.baseURL = "http://127.0.0.1:9/v1"    // nothing listens on port 9
        let provider = LLMProvider(host: host, requestBody: AppConfig.default.requestBody)
        do {
            for try await _ in provider.translateStream(text: "hi", from: "en", to: "ru") {}
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(ErrorMessage.text(for: error, serverURL: host.baseURL),
                           "No answer from http://127.0.0.1:9/v1. Is LM Studio or another server running, with a model loaded?")
        }
    }

    func testInvalidURL() {
        XCTAssertEqual(ErrorMessage.text(for: URLError(.badURL), serverURL: "nonsense"),
                       "The server URL in Settings is not valid: nonsense")
    }
}
