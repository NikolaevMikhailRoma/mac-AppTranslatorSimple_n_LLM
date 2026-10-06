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

/// Fixed behaviour that is not in Settings: changing it means changing the code.
public struct AppConfig: Equatable, Sendable {
    /// Request body parameters sent with every translation.
    public var requestBody: RequestBody

    public static let `default` = AppConfig(
        // max_tokens is replaced with the Developer setting before sending.
        requestBody: RequestBody(temperature: 0, max_tokens: 10_000, stream: false,
                                 tool_choice: nil, enable_thinking: nil)
    )
}
