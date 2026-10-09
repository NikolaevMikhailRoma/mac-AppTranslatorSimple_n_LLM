import Foundation

/// A way to get a translation, as Settings lists it. What runs it, the `TranslationProvider`,
/// is made by the app: some engines (the system translator) need a window to work in.
///
/// Adding a method: a case here; if it has settings, a struct in `Methods/<Name>/` and a field
/// in `Settings`; in the app, its provider and its panel under `Translation/Methods/<Name>/`.
/// The compiler points at every `switch` that needs the new case.
public enum TranslationMethod: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Stored as "host", its name before 0.0.4's refactoring.
    case localLLM = "host"
    case claude
    case appleTranslation = "apple"

    public var id: Self { self }

    /// What Settings lists, in this order: the LLMs, then the rest.
    public static let offered: [TranslationMethod] = [.localLLM, .claude, .appleTranslation]

    public var title: String {
        switch self {
        case .localLLM: return "Local LLM / own host"
        case .claude: return "Claude subscription"
        case .appleTranslation: return "macOS Translation"
        }
    }

    /// SF Symbol shown next to the title in Settings.
    public var symbol: String {
        switch self {
        case .localLLM: return "cpu"
        case .claude: return "sparkle"
        case .appleTranslation: return "apple.logo"
        }
    }

    /// LLMs work alike: a prompt with the target language, any source language. Settings groups them.
    public var isLLM: Bool {
        switch self {
        case .localLLM, .claude: return true
        case .appleTranslation: return false
        }
    }

    /// Whether the engine must be told the source. An LLM reads any language, so text that is not
    /// Cyrillic stays `auto`; the system translator (and web APIs) get the second language instead.
    var needsSource: Bool { !isLLM }

    /// Whether spaces and newlines around the answer are dropped (the LLM's Advanced setting).
    func trimsAnswer(_ settings: Settings) -> Bool {
        switch self {
        case .localLLM: return settings.localLLM.trimAnswer
        case .claude, .appleTranslation: return false
        }
    }
}
