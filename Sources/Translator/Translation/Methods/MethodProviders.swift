import TranslatorCore

extension TranslationMethod {
    /// The engine behind the method. Made in the app, not in Core: the system translator needs a window.
    @MainActor
    func makeProvider(_ settings: Settings) -> TranslationProvider {
        switch self {
        case .localLLM: return LocalLLMProvider(settings: settings.localLLM)
        case .claude: return ClaudeProvider(settings: settings.claude)
        case .appleTranslation: return AppleTranslationProvider()
        }
    }
}
