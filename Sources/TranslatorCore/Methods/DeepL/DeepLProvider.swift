import Foundation

/// DeepL through the free endpoint its browser extension uses (`oneshot-free`): no key, no account.
/// Not a public API: no guarantees, at most `maxLength` characters a request, and many requests
/// in a row may be refused for a while. Answers in one piece.
public final class DeepLProvider: TranslationProvider {
    public static let endpoint = URL(string: "https://oneshot-free.www.deepl.com/v1/translate")!
    /// Longer text gets HTTP 400 "text exceeds maximum length"; DeepL counts UTF-16 units.
    public static let maxLength = 1_500

    private let endpoint: URL
    private let session: URLSession

    public init(endpoint: URL = DeepLProvider.endpoint, session: URLSession = OpenAIClient.defaultSession) {
        self.endpoint = endpoint
        self.session = session
    }

    /// The source always comes from the app (`TranslationMethod.needsSource`), as for macOS Translation.
    public func translate(text: String, from source: String?, to target: String) async throws -> String {
        guard let source else { throw DeepLError.noSource }
        guard text.utf16.count <= Self.maxLength else { throw DeepLError.tooLong }
        // Nothing to translate; DeepL would refuse it.
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return text }
        do {
            let (data, response) = try await session.data(for: request(text, from: source, to: target))
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            switch status {
            case 200: return try Self.decode(data)
            case 429: throw DeepLError.tooManyRequests
            default: throw DeepLError.http(status)
            }
        } catch let error as URLError {
            switch error.code {
            case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .notConnectedToInternet, .timedOut:
                throw DeepLError.unreachable
            default:
                throw error
            }
        }
    }

    func request(_ text: String, from source: String, to target: String) throws -> URLRequest {
        var request = URLRequest(url: endpoint, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("None", forHTTPHeaderField: "Authorization")    // literally "None": no key
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "text": [text],
            "source_lang": source,
            "target_lang": Self.targetCode(target),
        ])
        return request
    }

    /// English as a target names its variant. Lower case: with "RU" this endpoint sends the text back
    /// untranslated, with HTTP 200 (2026-10-11), though the official API documents upper case.
    static func targetCode(_ code: String) -> String {
        code == "en" ? "en-US" : code
    }

    /// `{"translations":[{"detected_source_language":"en","text":"…"}]}`, one item per text sent.
    static func decode(_ data: Data) throws -> String {
        struct Translation: Decodable { let text: String }
        struct Response: Decodable { let translations: [Translation] }
        guard let answer = try? JSONDecoder().decode(Response.self, from: data).translations.first?.text else {
            throw DeepLError.unreadable
        }
        return answer
    }
}

public enum DeepLError: LocalizedError, Equatable {
    case noSource
    case tooLong
    case unreachable
    case tooManyRequests
    case http(Int)
    case unreadable

    public var errorDescription: String? {
        switch self {
        case .noSource:
            return "DeepL needs the source language."
        case .tooLong:
            return "DeepL without a key takes up to \(DeepLProvider.maxLength) characters at a time. Copy less or pick another method."
        case .unreachable:
            return "No answer from DeepL. Is the Mac online?"
        case .tooManyRequests:
            return "DeepL refuses requests from this address for now (too many). Try again later or pick another method."
        case .http(let status):
            return "DeepL answered with HTTP \(status)."
        case .unreadable:
            return "DeepL's answer could not be read: DeepL may have changed it."
        }
    }
}
