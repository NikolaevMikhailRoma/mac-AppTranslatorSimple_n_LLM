import Foundation
import Combine

// MARK: - Models

public struct RequestBody: Codable, Equatable {
    public var temperature: Double
    public var max_tokens: Int
    public var stream: Bool
    public var tool_choice: String?
    public var enable_thinking: Bool?

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "temperature": temperature,
            "max_tokens": max_tokens,
            "stream": stream
        ]
        if let toolChoice = tool_choice {
            dict["tool_choice"] = toolChoice
        }
        if let enableThinking = enable_thinking {
            dict["enable_thinking"] = enableThinking
        }
        return dict
    }
}

/// Minimal app configuration loaded from a single JSON file.
public struct AppConfig: Codable, Equatable {
    /// The base URL of the OpenAI-compatible API.
    public var baseURL: String
    /// The API key for the service. Optional, as local servers may not require one.
    public var apiKey: String?
    /// The identifier of the model to use. Optional, will rely on server's default if not provided.
    public var modelIdentifier: String?

    /// Language codes with the first treated as the user's initial language.
    public var languageCodes: [String]
    /// Optional regex rules for counting characters per language to detect source language.
    public var languageDetectionRegexes: [String: String]? = nil
    /// Time window in seconds to detect a double copy gesture.
    public var doubleCopyGapSeconds: Double
    /// Request body parameters.
    public var requestBody: RequestBody
    /// Maximum line length for the translated text.
    public var maxLineLength: Int?

    enum CodingKeys: String, CodingKey {
        case baseURL, apiKey, modelIdentifier, languageCodes, languageDetectionRegexes, doubleCopyGapSeconds, requestBody
        case maxLineLength
    }
}

// MARK: - Settings store (read-only)

/// Loads settings from JSON. Use SETTINGS_FILE env var to specify alternative config (e.g., "settings.openai").
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
            var loadedConfig = try decoder.decode(AppConfig.self, from: data)

            if loadedConfig.apiKey == nil || loadedConfig.apiKey?.isEmpty == true {
                if let keyURL = Bundle.main.url(forResource: ".openai-key", withExtension: nil),
                   let keyData = try? Data(contentsOf: keyURL),
                   let key = String(data: keyData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    loadedConfig.apiKey = key
                }
            }

            self.config = loadedConfig
            print("✓ Loaded configuration from \(settingsFileName).json")
        } catch {
            fatalError("Failed to load \(settingsFileName).json: \(error)")
        }
    }
}