import Foundation

/// Any OpenAI-compatible Chat Completions server: LM Studio, Ollama, llama.cpp and the like.
public struct LocalLLMSettings: Codable, Equatable, Sendable {
    /// Up to and including `/v1`, the way OpenAI-compatible servers print it.
    public var baseURL = "http://127.0.0.1:1234/v1"
    /// Empty means the model the server has loaded. Needed when the server has several.
    public var model = ""
    /// Advanced: the longest answer the model may write, in tokens.
    public var maxTokens = 8_192

    public static let maxTokensRange = 256...131_072

    /// The arrows next to the field move between powers of two: 4096 → 8192, 6000 → 4096.
    public static func nextMaxTokens(after value: Int, up: Bool) -> Int {
        var power = 1
        while power <= value { power *= 2 }   // the smallest power of two above value
        let next = up ? power : (power / 2 == value ? value / 2 : power / 2)
        return min(max(next, maxTokensRange.lowerBound), maxTokensRange.upperBound)
    }

    /// The system prompt; see `Prompt` for the placeholder.
    public var prompt = Prompt.standard
    /// Advanced: drop spaces and newlines the model puts before and after the translation.
    public var trimAnswer = false

    public init() {}
}
