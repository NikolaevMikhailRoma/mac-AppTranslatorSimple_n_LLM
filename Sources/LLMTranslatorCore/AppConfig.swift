import Foundation

// MARK: - Models

public struct RequestBody: Codable, Equatable, Sendable {
    public var temperature: Double
    public var max_tokens: Int
    public var stream: Bool
    public var tool_choice: String?
    public var enable_thinking: Bool?

    public func toDictionary() -> [String: Any] {
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
public struct AppConfig: Codable, Equatable, Sendable {
    /// The base URL of the LLM API endpoint.
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
