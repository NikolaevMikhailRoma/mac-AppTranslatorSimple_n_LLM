import Foundation

/// Picks the target language: mostly Cyrillic text goes into language 2, anything else into language 1.
public struct LanguageDetector: Sendable {
    private let native: String
    private let second: String

    public init(native: String, second: String) {
        self.native = native
        self.second = second
    }

    /// Ties go to Cyrillic, so text with no letters is translated into language 2.
    public func determineLanguageDirection(for text: String) -> (source: String, target: String) {
        let cyrillic = text.matches(of: /\p{Script=Cyrillic}/).count
        let otherLetters = text.matches(of: /\p{L}/).count - cyrillic
        return cyrillic >= otherLetters ? (native, second) : (second, native)
    }
}
