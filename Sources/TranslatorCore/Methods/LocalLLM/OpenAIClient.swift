import Foundation

/// Talks to an OpenAI-compatible server (LM Studio, Ollama, llama.cpp, OpenRouter…):
/// chat completions, whole or streamed, and the model list. Knows nothing about translation.
public struct OpenAIClient: Sendable {
    /// Up to and including `/v1`, the way these servers print it.
    public let baseURL: String
    private let apiKey: String?
    private let session: URLSession

    public init(baseURL: String, apiKey: String? = nil, session: URLSession = OpenAIClient.defaultSession) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.session = session
    }

    /// No caches or cookies: every request goes to the server.
    public static let defaultSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    // MARK: Requests

    /// A `/chat/completions` body. `extra` carries what a particular model or server needs on top.
    public static func chatBody(model: String, messages: [[String: String]], maxTokens: Int,
                                stream: Bool, extra: [String: Any] = [:]) throws -> Data {
        var body: [String: Any] = ["messages": messages, "temperature": 0, "max_tokens": maxTokens, "stream": stream]
        let model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        if !model.isEmpty { body["model"] = model }    // empty: the model the server has loaded
        body.merge(extra) { _, new in new }
        return try JSONSerialization.data(withJSONObject: body)
    }

    /// The whole answer at once (`stream: false` in the body).
    public func complete(_ body: Data) async throws -> String {
        do {
            let (data, response) = try await session.data(for: try request("chat/completions", body: body))
            try check(response)
            return try Self.decodeAnswer(data)
        } catch {
            throw explained(error)
        }
    }

    /// The answer piece by piece as the model writes (`stream: true` in the body): server-sent events.
    public func stream(_ body: Data) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await session.bytes(for: try request("chat/completions", body: body))
                    try check(response)
                    for try await line in bytes.lines {
                        switch Self.parseEvent(line) {
                        case .piece(let piece): continuation.yield(piece)
                        case .done: continuation.finish()    // keep reading until the server closes, so nothing is cancelled
                        case .skip: continue
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: explained(error))
                }
            }
            // Only a reader that gave up (a new ⌘C C, a closed popup) stops the request.
            continuation.onTermination = { termination in
                if case .cancelled = termination { task.cancel() }
            }
        }
    }

    /// The models the server offers: `GET /models`.
    public func models() async throws -> [String] {
        do {
            var request = try request("models", body: nil)
            request.timeoutInterval = 5
            let (data, response) = try await session.data(for: request)
            try check(response)
            return try Self.decodeModels(data)
        } catch {
            throw explained(error)
        }
    }

    // MARK: Parsing

    enum StreamEvent: Equatable {
        case piece(String)
        case done
        case skip
    }

    /// One SSE line: a piece of the answer, the end marker, or something to ignore (comments, empty pieces).
    static func parseEvent(_ line: String) -> StreamEvent {
        guard line.hasPrefix("data:") else { return .skip }
        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
        if payload == "[DONE]" { return .done }
        struct Delta: Decodable { let content: String? }
        struct Choice: Decodable { let delta: Delta? }
        struct Chunk: Decodable { let choices: [Choice] }
        guard let chunk = try? JSONDecoder().decode(Chunk.self, from: Data(payload.utf8)),
              let content = chunk.choices.first?.delta?.content, !content.isEmpty else { return .skip }
        return .piece(content)
    }

    static func decodeAnswer(_ data: Data) throws -> String {
        struct Message: Decodable { let content: String }
        struct Choice: Decodable { let message: Message }
        struct Response: Decodable { let choices: [Choice] }
        guard let answer = try JSONDecoder().decode(Response.self, from: data).choices.first?.message.content else {
            throw OpenAIClientError.emptyAnswer
        }
        return answer
    }

    static func decodeModels(_ data: Data) throws -> [String] {
        struct Model: Decodable { let id: String }
        struct Response: Decodable { let data: [Model] }
        return try JSONDecoder().decode(Response.self, from: data).data.map(\.id)
    }

    // MARK: Plumbing

    /// `baseURL` + `path`, tolerating spaces and a trailing slash in what the user typed.
    func url(_ path: String) -> URL? {
        var base = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while base.hasSuffix("/") { base.removeLast() }
        return URL(string: base + "/" + path)
    }

    private func request(_ path: String, body: Data?) throws -> URLRequest {
        guard let url = url(path), url.scheme != nil, url.host != nil else {
            throw OpenAIClientError.invalidURL(baseURL)
        }
        var request = URLRequest(url: url)
        if let body {
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        if let apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func check(_ response: URLResponse) throws {
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard status == 200 else { throw OpenAIClientError.http(status: status, server: baseURL) }
    }

    /// Network failures become a sentence for the popup; cancellation passes through untouched.
    private func explained(_ error: Error) -> Error {
        guard let urlError = error as? URLError else { return error }
        switch urlError.code {
        case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .notConnectedToInternet, .timedOut:
            return OpenAIClientError.unreachable(baseURL)
        case .badURL, .unsupportedURL:
            return OpenAIClientError.invalidURL(baseURL)
        default:
            return error
        }
    }
}

public enum OpenAIClientError: LocalizedError, Equatable {
    case invalidURL(String)
    case unreachable(String)
    case http(status: Int, server: String)
    case emptyAnswer

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "The server URL in Settings is not valid: \(url)"
        case .unreachable(let url):
            return "No answer from \(url). Is LM Studio or another server running, with a model loaded?"
        case .http(let status, let url):
            return "The server at \(url) answered with HTTP \(status). Check the server URL and the model in Settings."
        case .emptyAnswer:
            return "The model sent an empty answer."
        }
    }
}
