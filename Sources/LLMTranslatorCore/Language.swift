import Foundation

/// A language offered in Settings.
public struct Language: Identifiable, Hashable, Sendable {
    public let code: String

    public var id: String { code }

    /// For Settings, in the user's interface language.
    public var displayName: String {
        (Locale.current.localizedString(forLanguageCode: code) ?? code).capitalized(with: .current)
    }

    /// Language 1. The detector tells it apart by the Cyrillic alphabet, so only Russian for now.
    public static let native: [Language] = [Language(code: "ru")]

    /// Language 2: only the target of a translation, so any language the model knows.
    public static let second: [Language] = [
        "en", "de", "fr", "es", "it", "pt", "pl", "cs", "nl", "tr",
        "uk", "el", "ar", "he", "hi", "th", "zh", "ja", "ko",
    ].map(Language.init(code:))
}
