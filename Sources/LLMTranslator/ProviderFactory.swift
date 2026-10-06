import Foundation
import LLMTranslatorCore

/// A factory for creating translation providers.
enum ProviderFactory {
    /// Built for every translation, so a change in Settings applies to the next ⌘C C.
    static func createProvider(for settings: Settings, config: AppConfig) -> TranslationProvider {
        switch settings.method {
        case .host:
            var body = config.requestBody
            body.max_tokens = settings.host.maxTokens
            return LLMProvider(host: settings.host, requestBody: body, trimsWhitespace: settings.trimTranslation)
        }
    }
}
