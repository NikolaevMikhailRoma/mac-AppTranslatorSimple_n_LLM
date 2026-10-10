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
        try await client.complete(body(for: text, to: target, model: await model(), stream: false))
    }

    public func translateStream(text: String, from source: String?, to target: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let body = try body(for: text, to: target, model: await model(), stream: true)
                    for try await piece in client.stream(body) { continuation.yield(piece) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { termination in
                if case .cancelled = termination { task.cancel() }
            }
        }
    }

    /// The model from Settings; when the field is empty, the first one the server lists.
    /// LM Studio refuses a request without a model once it has two loaded.
    /// If the list cannot be read, the request goes without a model and the server says what is wrong.
    func model() async -> String {
        let chosen = settings.model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard chosen.isEmpty else { return chosen }
        return (try? await client.models().first) ?? ""
    }

    func messages(for text: String, to target: String) -> [[String: String]] {
        [
            ["role": "system", "content": Prompt.render(settings.prompt, target: target)],
            ["role": "user", "content": text],
        ]
    }

    /// No thinking before the translation: a reasoning model (Qwen 3.8 27B in LM Studio) otherwise spends
    /// seconds in `reasoning_content`, which the popup does not show. Models that do not reason ignore it.
    static var extra: [String: Any] { ["reasoning_effort": "none"] }

    func body(for text: String, to target: String, model: String, stream: Bool) throws -> Data {
        try OpenAIClient.chatBody(model: model, messages: messages(for: text, to: target),
                                  maxTokens: settings.maxTokens, stream: stream, extra: Self.extra)
    }
}
