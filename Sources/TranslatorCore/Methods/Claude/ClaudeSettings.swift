import Foundation

/// Claude through the user's subscription, by way of Claude Code installed on this Mac.
public struct ClaudeSettings: Codable, Equatable, Sendable {
    /// The `claude` command. Empty: the first of `ClaudeCode.searchPaths` that exists.
    public var executable = ""
    /// A Claude Code alias (`haiku`, `sonnet`, `opus`) or a full model name. Haiku answers fastest.
    public var model = "haiku"
    /// How much the model thinks before answering. Empty: Claude Code's default for the model.
    public var effort = ""
    /// The system prompt; see `Prompt` for the placeholder.
    public var prompt = Prompt.standard

    /// What `--effort` takes, for when Claude Code has not listed a model's own levels yet.
    public static let effortLevels = ["low", "medium", "high", "xhigh", "max"]

    public init() {}
}
