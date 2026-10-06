import Foundation

/// Picks the target language: text goes into language 1, mostly Cyrillic text into language 2.
public struct LanguageDetector: Sendable {
    private let language1: String
    private let language2: String

    public init(language1: String, language2: String) {
        self.language1 = language1
        self.language2 = language2
    }

    /// Ties go to Cyrillic, so text with no letters is translated into language 2.
    public func direction(for text: String) -> (source: String, target: String) {
        let cyrillic = text.matches(of: /\p{Script=Cyrillic}/).count
        let otherLetters = text.matches(of: /\p{L}/).count - cyrillic
        return cyrillic >= otherLetters ? (language1, language2) : (language2, language1)
    }
}
