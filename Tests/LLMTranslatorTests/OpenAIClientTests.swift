import XCTest
@testable import LLMTranslatorCore

final class OpenAIClientTests: XCTestCase {
    func testParsesLMStudioChunks() {
        XCTAssertEqual(OpenAIClient.parseEvent(#"data: {"choices":[{"index":0,"delta":{"role":"assistant","content":"При"}}]}"#),
                       .piece("При"))
        XCTAssertEqual(OpenAIClient.parseEvent(#"data: {"choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}"#), .skip)
        XCTAssertEqual(OpenAIClient.parseEvent("data: [DONE]"), .done)
        XCTAssertEqual(OpenAIClient.parseEvent(""), .skip)
        XCTAssertEqual(OpenAIClient.parseEvent(": keep-alive"), .skip)
    }

    func testDecodesWholeAnswerAsIs() throws {
        let data = Data(#"{"choices":[{"message":{"role":"assistant","content":"  Привет\n"}}]}"#.utf8)
        XCTAssertEqual(try OpenAIClient.decodeAnswer(data), "  Привет\n")
    }

    func testDecodesLMStudioModelList() throws {
        let data = Data(#"{"data":[{"id":"qwen/qwen3.5-9b","object":"model"},{"id":"gemma-3"}],"object":"list"}"#.utf8)
        XCTAssertEqual(try OpenAIClient.decodeModels(data), ["qwen/qwen3.5-9b", "gemma-3"])
    }

    func testURLs() {
        XCTAssertEqual(OpenAIClient(baseURL: "http://127.0.0.1:1234/v1").url("models")?.absoluteString,
                       "http://127.0.0.1:1234/v1/models")
        XCTAssertEqual(OpenAIClient(baseURL: " http://localhost:11434/v1/ ").url("chat/completions")?.absoluteString,
                       "http://localhost:11434/v1/chat/completions")
    }

    func testChatBody() throws {
        let data = try OpenAIClient.chatBody(model: " qwen ", messages: [["role": "user", "content": "Hi"]],
                                             maxTokens: 8_192, stream: true)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["model"] as? String, "qwen")
        XCTAssertEqual(json["temperature"] as? Double, 0)
        XCTAssertEqual(json["max_tokens"] as? Int, 8_192)
        XCTAssertEqual(json["stream"] as? Bool, true)
        XCTAssertNil(json["enable_thinking"], "not sent: Qwen does not honour it reliably")
    }

    func testEmptyModelIsNotSent() throws {
        let data = try OpenAIClient.chatBody(model: "", messages: [], maxTokens: 1, stream: false)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNil(json?["model"], "an empty model means the one loaded on the server")
    }

    func testServerDownIsReadable() async {
        let client = OpenAIClient(baseURL: "http://127.0.0.1:9/v1")    // nothing listens on port 9
        do {
            _ = try await client.models()
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error.localizedDescription,
                           "No answer from http://127.0.0.1:9/v1. Is LM Studio or another server running, with a model loaded?")
        }
    }

    func testStreamFromDownServerFails() async {
        let client = OpenAIClient(baseURL: "http://127.0.0.1:9/v1")
        do {
            for try await _ in client.stream(Data("{}".utf8)) {}
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? OpenAIClientError, .unreachable("http://127.0.0.1:9/v1"))
        }
    }

    func testInvalidURL() async {
        do {
            _ = try await OpenAIClient(baseURL: "nonsense").models()
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error.localizedDescription, "The server URL in Settings is not valid: nonsense")
        }
    }
}
