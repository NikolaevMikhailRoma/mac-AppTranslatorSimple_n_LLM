import Foundation

/// Abstraction for translation engines.
/// Implementations can route to local models, remote HTTP APIs, etc.
public protocol TranslationProvider: AnyObject, Sendable {
    /// Translates the provided text from `sourceLanguageCode` to `targetLanguageCode`.
    /// - Parameters:
    ///   - text: Input text to translate.
    ///   - sourceLanguageCode: BCP-47 language code of the source text (e.g., "en", "ru").
    ///   - targetLanguageCode: BCP-47 language code of the desired output.
    /// - Returns: The translated text, without extra commentary.
    func translate(text: String, from sourceLanguageCode: String, to targetLanguageCode: String) async throws -> String

    /// The translation in pieces as they arrive. Methods that cannot stream use the default: one piece.
    func translateStream(text: String, from sourceLanguageCode: String, to targetLanguageCode: String)
        -> AsyncThrowingStream<String, Error>
}

public extension TranslationProvider {
    func translateStream(text: String, from sourceLanguageCode: String, to targetLanguageCode: String)
        -> AsyncThrowingStream<String, Error> {
        translateOnce(text: text, from: sourceLanguageCode, to: targetLanguageCode)
    }

    /// The whole translation as a single piece, also for methods that could stream but are told not to.
    func translateOnce(text: String, from sourceLanguageCode: String, to targetLanguageCode: String)
        -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    continuation.yield(try await translate(text: text, from: sourceLanguageCode, to: targetLanguageCode))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

