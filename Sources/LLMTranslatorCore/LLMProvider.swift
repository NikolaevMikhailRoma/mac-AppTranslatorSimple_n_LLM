import Foundation

/// A provider that connects to any Chat Completions API endpoint.
public final class LLMProvider: TranslationProvider {
    private let session: URLSession
    private let host: HostSettings
    private let requestBody: RequestBody
    private let apiKey: String?
    private let trimsWhitespace: Bool

    public init(host: HostSettings, requestBody: RequestBody, trimsWhitespace: Bool = true,
                apiKey: String? = nil, session: URLSession? = nil) {
        self.host = host
        self.requestBody = requestBody
        self.trimsWhitespace = trimsWhitespace
        self.apiKey = apiKey
        if let session = session {
            self.session = session
        } else {
            let cfg = URLSessionConfiguration.default
            cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
            cfg.urlCache = nil
            cfg.httpShouldSetCookies = false
            cfg.httpCookieAcceptPolicy = .never
            cfg.allowsExpensiveNetworkAccess = true
            cfg.allowsConstrainedNetworkAccess = true
            cfg.waitsForConnectivity = false
            self.session = URLSession(configuration: cfg)
        }
    }

    public func translate(text: String, from sourceLanguageCode: String, to targetLanguageCode: String) async throws -> String {
        let messages = buildMessages(for: text, from: sourceLanguageCode, to: targetLanguageCode)
        let payload  = try makeRequestPayload(messages: messages)
        let data     = try await post(payload)
        let response = try extractAnswer(from: data)
        return response
    }

    // MARK: - Networking helpers
    private func post(_ body: Data) async throws -> Data {
        guard let endpoint = host.chatCompletionsURL else {
            throw NSError(domain: "LLMProvider", code: 100,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid server URL in Settings: \(host.baseURL)"])
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = body
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "LLMProvider", code: statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "The API endpoint is not reachable or returned an error. Status: \(statusCode)"])
        }
        return data
    }

    func extractAnswer(from data: Data) throws -> String {
        struct Message: Decodable { let role: String; let content: String }
        struct Choice: Decodable { let message: Message }
        struct ResponseBody: Decodable { let choices: [Choice] }
        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        guard let raw = decoded.choices.first?.message.content else {
            throw NSError(domain: "LLMProvider", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Empty response from language model"])
        }
        return trimsWhitespace ? raw.trimmingCharacters(in: .whitespacesAndNewlines) : raw
    }

    // MARK: - Payload builder
    func makeRequestPayload(messages: [[String: String]]) throws -> Data {
        var dict = requestBody.toDictionary()

        let model = host.model.trimmingCharacters(in: .whitespacesAndNewlines)
        if !model.isEmpty {
            dict["model"] = model
        }
        
        dict["messages"] = messages
        return try JSONSerialization.data(withJSONObject: dict, options: [])
    }

    // MARK: - Prompt construction
    func buildMessages(for text: String, from srcLang: String, to dstLang: String) -> [[String: String]] {
        // The source language is not sent: it is only a guess, and the model sees the text anyway.
        let systemPrompt = host.prompt.replacingOccurrences(of: "{to}", with: dstLang)

        return [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": text]
        ]
    }
}