import Foundation

/// One translation, ready to run: what is translated, in which direction, and the answer's pieces.
public struct TranslationJob: Sendable {
    /// The copied text after joining broken lines; also what sizes the popup.
    public let text: String
    /// Known only for Cyrillic text; see `LanguageDetector`.
    public let source: String?
    public let target: String
    /// Whether spaces and newlines around the answer are dropped (an Advanced setting of the method).
    public let trimsAnswer: Bool
    public let pieces: AsyncThrowingStream<String, Error>
}

/// Everything between ⌘C C and the answer that needs no screen: joining lines, the direction,
/// running the method's provider. The app makes the provider and only shows what comes out.
public enum TranslationPipeline {
    public static func start(_ copied: String, settings: Settings, provider: TranslationProvider) -> TranslationJob {
        let text = settings.joinBrokenLines ? LineJoiner.join(copied) : copied
        let (source, target) = LanguageDetector(language1: settings.language1, language2: settings.language2)
            .direction(for: text)
        let pieces = settings.developer.streamLLM
            ? provider.translateStream(text: text, from: source, to: target)
            : provider.translateOnce(text: text, from: source, to: target)
        return TranslationJob(text: text, source: source, target: target,
                              trimsAnswer: settings.method.trimsAnswer(settings), pieces: pieces)
    }
}
