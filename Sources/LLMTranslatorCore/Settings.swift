import Foundation

/// A way to get a translation. Only the user's own host works so far.
public enum TranslationMethod: String, Codable, CaseIterable, Identifiable, Sendable {
    case host

    public var id: Self { self }

    public var title: String {
        switch self {
        case .host: return "Local LLM / own host"
        }
    }
}

/// Any OpenAI-compatible Chat Completions server: LM Studio, Ollama, llama.cpp and the like.
public struct HostSettings: Codable, Equatable, Sendable {
    /// Up to and including `/v1`, the way OpenAI-compatible servers print it.
    public var baseURL = "http://127.0.0.1:1234/v1"
    /// Empty means the model the server has loaded.
    public var model = ""
    /// `{from}` and `{to}` are replaced with language codes such as `ru` and `en`.
    public var prompt = HostSettings.defaultPrompt

    public static let defaultPrompt = """
        Translate from {from} to {to}.
        Preserve every character of formatting: spaces, newlines, tabs, punctuation, emojis, special symbols.
        Output ONLY the translation, nothing else.
        """

    public init() {}

    public var chatCompletionsURL: URL? {
        var base = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while base.hasSuffix("/") { base.removeLast() }
        return URL(string: base + "/chat/completions")
    }

    // A key missing from stored settings falls back to its default instead of dropping them all.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = HostSettings()
        baseURL = try c.decodeIfPresent(String.self, forKey: .baseURL) ?? fallback.baseURL
        model = try c.decodeIfPresent(String.self, forKey: .model) ?? fallback.model
        prompt = try c.decodeIfPresent(String.self, forKey: .prompt) ?? fallback.prompt
    }
}

/// Tuning a regular user never needs: the Developer tab.
public struct DeveloperSettings: Codable, Equatable, Sendable {
    /// Two copies closer than this count as ⌘C C.
    public var doubleCopyGapSeconds = 0.3
    /// Longer lines in the popup are wrapped at a word boundary; 0 turns wrapping off.
    public var maxLineLength = 160
    /// The menu bar icon turns red while a translation request is running.
    public var highlightIconWhileTranslating = true

    public static let doubleCopyGapRange = 0.1...1.0
    public static let maxLineLengthRange = 0...400

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = DeveloperSettings()
        doubleCopyGapSeconds = try c.decodeIfPresent(Double.self, forKey: .doubleCopyGapSeconds) ?? fallback.doubleCopyGapSeconds
        maxLineLength = try c.decodeIfPresent(Int.self, forKey: .maxLineLength) ?? fallback.maxLineLength
        highlightIconWhileTranslating = try c.decodeIfPresent(Bool.self, forKey: .highlightIconWhileTranslating)
            ?? fallback.highlightIconWhileTranslating
    }
}

/// Everything the user can change in Settings. Stored as JSON in UserDefaults.
public struct Settings: Codable, Equatable, Sendable {
    public var method: TranslationMethod = .host
    public var host = HostSettings()
    /// Language 1: mostly Cyrillic text is translated out of it, anything else into it.
    public var nativeLanguage = "ru"
    /// Language 2: the target for text in language 1.
    public var secondLanguage = "en"
    public var developer = DeveloperSettings()

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = Settings()
        method = (try? c.decodeIfPresent(TranslationMethod.self, forKey: .method)) ?? fallback.method
        host = try c.decodeIfPresent(HostSettings.self, forKey: .host) ?? fallback.host
        nativeLanguage = try c.decodeIfPresent(String.self, forKey: .nativeLanguage) ?? fallback.nativeLanguage
        secondLanguage = try c.decodeIfPresent(String.self, forKey: .secondLanguage) ?? fallback.secondLanguage
        developer = try c.decodeIfPresent(DeveloperSettings.self, forKey: .developer) ?? fallback.developer
    }
}
