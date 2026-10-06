import Foundation

/// A way to get a translation. Only a local LLM (or the user's own host) works so far.
///
/// Adding a method: a case here, its provider (`TranslationProvider`) and settings struct in
/// `Methods/<Name>/`, a field for those settings in `Settings`, and its panel in the app's
/// Translation tab. The compiler points at every `switch` that needs the new case.
public enum TranslationMethod: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Stored as "host", its name before 0.0.4's refactoring.
    case localLLM = "host"

    public var id: Self { self }

    public var title: String {
        switch self {
        case .localLLM: return "Local LLM / own host"
        }
    }

    /// SF Symbol shown next to the title in Settings.
    public var symbol: String {
        switch self {
        case .localLLM: return "cpu"
        }
    }

    public func makeProvider(_ settings: Settings) -> TranslationProvider {
        switch self {
        case .localLLM: return LocalLLMProvider(settings: settings.localLLM)
        }
    }

    func trimsAnswer(_ settings: Settings) -> Bool {
        switch self {
        case .localLLM: return settings.localLLM.trimAnswer
        }
    }
}
