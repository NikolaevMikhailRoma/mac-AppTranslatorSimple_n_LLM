import Foundation
import Combine
import LLMTranslatorCore

// MARK: - Settings store (read-only)

/// Loads settings from JSON. Use SETTINGS_FILE env var to specify alternative config.
@MainActor
public final class SettingsStore: ObservableObject {
    public static let shared = SettingsStore()

    /// Immutable configuration used by the app.
    @Published public private(set) var config: AppConfig

    private init() {
        let settingsFileName = ProcessInfo.processInfo.environment["SETTINGS_FILE"] ?? "settings"

        guard let url = Bundle.main.url(forResource: settingsFileName, withExtension: "json") else {
            fatalError("Missing \(settingsFileName).json in bundle. Add it to the target resources.")
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let loadedConfig = try decoder.decode(AppConfig.self, from: data)

            self.config = loadedConfig
            print("✓ Loaded configuration from \(settingsFileName).json")
        } catch {
            fatalError("Failed to load \(settingsFileName).json: \(error)")
        }
    }
}