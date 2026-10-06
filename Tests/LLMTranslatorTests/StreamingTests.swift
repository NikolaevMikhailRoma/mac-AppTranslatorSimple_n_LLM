import XCTest
@testable import LLMTranslatorCore

final class StreamingTests: XCTestCase {
    func testParsesLMStudioChunks() {
        XCTAssertEqual(LLMProvider.parseEvent(#"data: {"choices":[{"index":0,"delta":{"role":"assistant","content":"При"}}]}"#),
                       .piece("При"))
        XCTAssertEqual(LLMProvider.parseEvent(#"data: {"choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}"#), .skip)
        XCTAssertEqual(LLMProvider.parseEvent("data: [DONE]"), .done)
        XCTAssertEqual(LLMProvider.parseEvent(""), .skip)
        XCTAssertEqual(LLMProvider.parseEvent(": keep-alive"), .skip)
    }

    func testStreamingPayloadAsksForStream() throws {
        let p = LLMProvider(host: HostSettings(), requestBody: AppConfig.default.requestBody)
        let json = try JSONSerialization.jsonObject(with: p.makeRequestPayload(messages: [], stream: true)) as? [String: Any]
        XCTAssertEqual(json?["stream"] as? Bool, true)
    }

    /// A method that cannot stream still works through translateStream: one piece.
    func testDefaultStreamYieldsWholeTranslation() async throws {
        final class Fixed: TranslationProvider {
            func translate(text: String, from: String, to: String) async throws -> String { "whole" }
        }
        var pieces: [String] = []
        for try await piece in Fixed().translateStream(text: "x", from: "ru", to: "en") { pieces.append(piece) }
        XCTAssertEqual(pieces, ["whole"])
    }

    func testStreamingOffGivesOnePiece() async throws {
        final class Chunky: TranslationProvider {
            func translate(text: String, from: String, to: String) async throws -> String { "ab" }
            func translateStream(text: String, from: String, to: String) -> AsyncThrowingStream<String, Error> {
                AsyncThrowingStream { $0.yield("a"); $0.yield("b"); $0.finish() }
            }
        }
        let service = TranslationService(provider: Chunky(), languageDetector: LanguageDetector(native: "ru", second: "en"))
        var on: [String] = [], off: [String] = []
        for try await p in service.stream("hi", streaming: true).pieces { on.append(p) }
        for try await p in service.stream("hi", streaming: false).pieces { off.append(p) }
        XCTAssertEqual(on, ["a", "b"])
        XCTAssertEqual(off, ["ab"])
    }
}
