import Foundation

/// Tuning a regular user never needs: the Developer tab.
public struct DeveloperSettings: Codable, Equatable, Sendable {
    /// Two copies closer than this count as ⌘C C.
    public var doubleCopyGapSeconds = 0.3
    /// The popup grows with the text up to this width in points, then wraps it on screen only:
    /// no newline is added to what gets copied or selected.
    public var popupMaxWidth = 640
    /// The popup opens at the original's size × this, before the translation's real size is known.
    public var popupGrowth = 1.2
    /// LLM answers arrive word by word. Off: the popup appears with the whole translation at once.
    public var streamLLM = true
    /// The menu bar icon turns red while a translation request is running.
    public var highlightIconWhileTranslating = true

    public static let doubleCopyGapRange = 0.1...1.0
    public static let popupMaxWidthRange = 320...1_200
    public static let popupGrowthRange = 1.0...2.0

    public init() {}

}

/// Everything the user can change in Settings. Stored as JSON in UserDefaults.
public struct Settings: Codable, Equatable, Sendable {
    public var method: TranslationMethod = .localLLM
    public var localLLM = LocalLLMSettings()
    public var claude = ClaudeSettings()
    /// Text is translated into language 1…
    public var language1 = "ru"
    /// …and mostly Cyrillic text into language 2.
    public var language2 = "en"
    /// Before translating, glue lines broken by the layout (PDF, e-mail); any method.
    public var joinBrokenLines = true
    /// Put the translation on the clipboard as soon as it arrives, without ⌘C in the popup.
    public var copyTranslation = false
    public var developer = DeveloperSettings()

    /// The stored names; some are older than the properties.
    enum CodingKeys: String, CodingKey {
        case method, claude, joinBrokenLines, copyTranslation, developer
        case localLLM = "host"
        case language1 = "nativeLanguage"
        case language2 = "secondLanguage"
    }

    public init() {}

    /// Stored settings over the defaults. Unreadable data gives the defaults; an earlier default
    /// prompt is upgraded to the current one, a prompt the user wrote is kept.
    public static func decode(from data: Data) -> Settings {
        guard var settings = try? SettingsCoding.decode(Settings.self, from: data, defaults: Settings()) else {
            return Settings()
        }
        if Prompt.earlierStandards.contains(settings.localLLM.prompt) {
            settings.localLLM.prompt = Prompt.standard
        }
        return settings
    }
}
