import Foundation
import LLMTranslatorCore

/// A factory for creating translation providers.
final class ProviderFactory {
    /// Creates and returns a `TranslationProvider` instance.
    /// - Parameter config: The application's configuration.
    /// - Returns: A concrete instance of a `TranslationProvider`.
    static func createProvider(for config: AppConfig) -> TranslationProvider {
        // Currently, we only have one provider type.
        // This factory can be extended in the future if other provider types are added.
        return LLMProvider(config: config)
    }
}