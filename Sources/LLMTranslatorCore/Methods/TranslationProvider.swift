import Foundation

/// A translation engine: a local model, a web API, the system translator.
public protocol TranslationProvider: AnyObject, Sendable {
    /// The whole translation of `text` into `target` (a language code such as "ru"), without commentary.
    /// `source` is nil when the app cannot tell the language; the engine detects it or does without.
    func translate(text: String, from source: String?, to target: String) async throws -> String

    /// The translation in pieces as they arrive. Engines that cannot stream use the default: one piece.
    func translateStream(text: String, from source: String?, to target: String) -> AsyncThrowingStream<String, Error>
}

public extension TranslationProvider {
    func translateStream(text: String, from source: String?, to target: String) -> AsyncThrowingStream<String, Error> {
        translateOnce(text: text, from: source, to: target)
    }

    /// The whole translation as a single piece, also for engines that could stream but are told not to.
    func translateOnce(text: String, from source: String?, to target: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    continuation.yield(try await translate(text: text, from: source, to: target))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
