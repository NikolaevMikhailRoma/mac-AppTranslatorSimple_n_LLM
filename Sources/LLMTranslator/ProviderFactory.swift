import Foundation
import LLMTranslatorCore

/// A factory for creating translation providers.
enum ProviderFactory {
    /// Built for every translation, so a change in Settings applies to the next ⌘C C.
    static func createProvider(for settings: Settings, config: AppConfig) -> TranslationProvider {
        switch settings.method {
        case .host:
            return LLMProvider(host: settings.host, requestBody: config.requestBody)
        }
    }
}
