import Foundation

/// Claude through the user's subscription: each translation is one run of Claude Code, streamed.
public final class ClaudeProvider: TranslationProvider {
    private let settings: ClaudeSettings

    public init(settings: ClaudeSettings) {
        self.settings = settings
    }

    public func translate(text: String, from source: String?, to target: String) async throws -> String {
        var answer = ""
        for try await piece in translateStream(text: text, from: source, to: target) { answer += piece }
        return answer
    }

    public func translateStream(text: String, from source: String?, to target: String) -> AsyncThrowingStream<String, Error> {
        guard let claude = ClaudeCode.find(settings.executable) else {
            let error = ClaudeCodeError.notFound(settings.executable.trimmingCharacters(in: .whitespacesAndNewlines))
            return AsyncThrowingStream { $0.finish(throwing: error) }
        }
        return claude.translate(text, systemPrompt: Prompt.render(settings.prompt, target: target),
                                model: settings.model, effort: settings.effort)
    }
}
