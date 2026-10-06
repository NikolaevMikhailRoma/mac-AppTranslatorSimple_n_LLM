import XCTest
@testable import TranslatorCore

final class TranslationProviderTests: XCTestCase {
    /// A method that cannot stream still works through translateStream: one piece.
    func testDefaultStreamYieldsWholeTranslation() async throws {
        final class Fixed: TranslationProvider {
            func translate(text: String, from: String, to: String) async throws -> String { "whole" }
        }
        var pieces: [String] = []
        for try await piece in Fixed().translateStream(text: "x", from: "ru", to: "en") { pieces.append(piece) }
        XCTAssertEqual(pieces, ["whole"])
    }

    func testOnceGivesOnePieceEvenForAStreamingProvider() async throws {
        final class Chunky: TranslationProvider {
            func translate(text: String, from: String, to: String) async throws -> String { "ab" }
            func translateStream(text: String, from: String, to: String) -> AsyncThrowingStream<String, Error> {
                AsyncThrowingStream { $0.yield("a"); $0.yield("b"); $0.finish() }
            }
        }
        var streamed: [String] = [], once: [String] = []
        for try await p in Chunky().translateStream(text: "hi", from: "ru", to: "en") { streamed.append(p) }
        for try await p in Chunky().translateOnce(text: "hi", from: "ru", to: "en") { once.append(p) }
        XCTAssertEqual(streamed, ["a", "b"])
        XCTAssertEqual(once, ["ab"])
    }
}
