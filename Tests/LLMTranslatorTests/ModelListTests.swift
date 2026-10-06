import XCTest
@testable import LLMTranslatorCore

final class ModelListTests: XCTestCase {
    func testDecodesLMStudioAnswer() throws {
        let data = Data(#"{"data":[{"id":"qwen/qwen3.5-9b","object":"model"},{"id":"gemma-3"}],"object":"list"}"#.utf8)
        XCTAssertEqual(try ModelList.decode(data), ["qwen/qwen3.5-9b", "gemma-3"])
    }

    func testModelsURL() {
        XCTAssertEqual(HostSettings().modelsURL?.absoluteString, "http://127.0.0.1:1234/v1/models")
    }
}
