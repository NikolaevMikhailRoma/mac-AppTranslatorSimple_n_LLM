import Foundation

/// Translation by a model on an OpenAI-compatible server: the prompt names the target language,
/// the copied text goes as the user message. The source language is not sent: it is only a guess,
/// and the model sees the text anyway.
/// The whole path and the decisions behind it: LLM-Translation-Pipeline.md in the repo root.
public final class LocalLLMProvider: TranslationProvider {
    private let settings: LocalLLMSettings
    private let client: OpenAIClient

    public init(settings: LocalLLMSettings, client: OpenAIClient? = nil) {
        self.settings = settings
        self.client = client ?? OpenAIClient(baseURL: settings.baseURL)
    }

    public func translate(text: String, from source: String?, to target: String) async throws -> String {
        try await client.complete(body(for: text, to: target, stream: false))
    }

    public func translateStream(text: String, from source: String?, to target: String) -> AsyncThrowingStream<String, Error> {
        do {
            return client.stream(try body(for: text, to: target, stream: true))
        } catch {
            return AsyncThrowingStream { $0.finish(throwing: error) }
        }
    }

    func messages(for text: String, to target: String) -> [[String: String]] {
        [
            ["role": "system", "content": Prompt.render(settings.prompt, target: target)],
            ["role": "user", "content": text],
        ]
    }

    func body(for text: String, to target: String, stream: Bool) throws -> Data {
        try OpenAIClient.chatBody(model: settings.model, messages: messages(for: text, to: target),
                                  maxTokens: settings.maxTokens, stream: stream)
    }
}
