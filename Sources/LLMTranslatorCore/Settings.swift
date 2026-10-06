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

    /// SF Symbol shown next to the title in Settings.
    public var symbol: String {
        switch self {
        case .host: return "cpu"
        }
    }
}

/// Any OpenAI-compatible Chat Completions server: LM Studio, Ollama, llama.cpp and the like.
public struct HostSettings: Codable, Equatable, Sendable {
    /// Up to and including `/v1`, the way OpenAI-compatible servers print it.
    public var baseURL = "http://127.0.0.1:1234/v1"
    /// Empty means the model the server has loaded. Needed when the server has several.
    public var model = ""
    /// Advanced: the longest answer the model may write, in tokens.
    public var maxTokens = 8_192

    public static let maxTokensRange = 256...131_072

    /// The arrows next to the field move between powers of two: 4096 → 8192, 6000 → 4096.
    public static func nextMaxTokens(after value: Int, up: Bool) -> Int {
        var power = 1
        while power <= value { power *= 2 }   // the smallest power of two above value
        let next = up ? power : (power / 2 == value ? value / 2 : power / 2)
        return min(max(next, maxTokensRange.lowerBound), maxTokensRange.upperBound)
    }
    /// `{to}` is replaced with the target language code, such as `ru` or `en`.
    public var prompt = HostSettings.defaultPrompt

    public static let defaultPrompt = """
        Translate to {to}.
        Preserve every character of formatting: spaces, newlines, tabs, punctuation, emojis, special symbols.
        Output ONLY the translation, nothing else.
        """

    /// The 0.0.4 draft default; a stored copy of it is upgraded to `defaultPrompt`.
    static let previousDefaultPrompt = """
        Translate from {from} to {to}.
        Preserve every character of formatting: spaces, newlines, tabs, punctuation, emojis, special symbols.
        Output ONLY the translation, nothing else.
        """

    public init() {}

    public var chatCompletionsURL: URL? { endpoint("chat/completions") }

    /// The models the server offers: `GET /v1/models`.
    public var modelsURL: URL? { endpoint("models") }

    private func endpoint(_ path: String) -> URL? {
        var base = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while base.hasSuffix("/") { base.removeLast() }
        return URL(string: base + "/" + path)
    }

    // A key missing from stored settings falls back to its default instead of dropping them all.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = HostSettings()
        baseURL = try c.decodeIfPresent(String.self, forKey: .baseURL) ?? fallback.baseURL
        model = try c.decodeIfPresent(String.self, forKey: .model) ?? fallback.model
        maxTokens = try c.decodeIfPresent(Int.self, forKey: .maxTokens) ?? fallback.maxTokens
        let stored = try c.decodeIfPresent(String.self, forKey: .prompt)
        prompt = stored == nil || stored == Self.previousDefaultPrompt ? fallback.prompt : stored!
    }
}

/// Tuning a regular user never needs: the Developer tab.
public struct DeveloperSettings: Codable, Equatable, Sendable {
    /// Two copies closer than this count as ⌘C C.
    public var doubleCopyGapSeconds = 0.3
    /// The popup grows with the text up to this width in points, then wraps it on screen only:
    /// no newline is added to what gets copied or selected.
    public var popupMaxWidth = 640
    /// The menu bar icon turns red while a translation request is running.
    public var highlightIconWhileTranslating = true

    public static let doubleCopyGapRange = 0.1...1.0
    public static let popupMaxWidthRange = 320...1_200

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = DeveloperSettings()
        doubleCopyGapSeconds = try c.decodeIfPresent(Double.self, forKey: .doubleCopyGapSeconds) ?? fallback.doubleCopyGapSeconds
        popupMaxWidth = try c.decodeIfPresent(Int.self, forKey: .popupMaxWidth) ?? fallback.popupMaxWidth
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
    /// Before translating, glue lines broken by the layout (PDF, e-mail); any method.
    public var joinBrokenLines = true
    /// Drop spaces and newlines the model puts before and after the translation.
    public var trimTranslation = true
    /// Put the translation on the clipboard as soon as it arrives, without ⌘C in the popup.
    public var copyTranslation = false
    public var developer = DeveloperSettings()

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = Settings()
        method = (try? c.decodeIfPresent(TranslationMethod.self, forKey: .method)) ?? fallback.method
        host = try c.decodeIfPresent(HostSettings.self, forKey: .host) ?? fallback.host
        nativeLanguage = try c.decodeIfPresent(String.self, forKey: .nativeLanguage) ?? fallback.nativeLanguage
        secondLanguage = try c.decodeIfPresent(String.self, forKey: .secondLanguage) ?? fallback.secondLanguage
        joinBrokenLines = try c.decodeIfPresent(Bool.self, forKey: .joinBrokenLines) ?? fallback.joinBrokenLines
        trimTranslation = try c.decodeIfPresent(Bool.self, forKey: .trimTranslation) ?? fallback.trimTranslation
        copyTranslation = try c.decodeIfPresent(Bool.self, forKey: .copyTranslation) ?? fallback.copyTranslation
        developer = try c.decodeIfPresent(DeveloperSettings.self, forKey: .developer) ?? fallback.developer
    }
}
