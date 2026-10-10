import Foundation

/// Google Translate through the free endpoint its own web page uses (`client=gtx`): no key, no account.
/// Not a public API: no guarantees, and many requests in a row from one address get blocked for a while.
/// Answers in one piece.
public final class GoogleTranslateProvider: TranslationProvider {
    public static let endpoint = URL(string: "https://translate.googleapis.com/translate_a/single")!

    private let endpoint: URL
    private let session: URLSession

    public init(endpoint: URL = GoogleTranslateProvider.endpoint, session: URLSession = OpenAIClient.defaultSession) {
        self.endpoint = endpoint
        self.session = session
    }

    /// The source always comes from the app (`TranslationMethod.needsSource`), as for macOS Translation:
    /// Google's own detection guesses wrong.
    public func translate(text: String, from source: String?, to target: String) async throws -> String {
        guard let source else { throw GoogleTranslateError.noSource }
        do {
            let (data, response) = try await session.data(for: request(text, from: source, to: target))
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            switch status {
            case 200: return try Self.decode(data)
            case 429: throw GoogleTranslateError.tooManyRequests
            default: throw GoogleTranslateError.http(status)
            }
        } catch let error as URLError {
            switch error.code {
            case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .notConnectedToInternet, .timedOut:
                throw GoogleTranslateError.unreachable
            default:
                throw error
            }
        }
    }

    /// POST, the text in the body: in the URL Google refuses long texts (HTTP 400 at about 20 000 characters).
    func request(_ text: String, from source: String, to target: String) -> URLRequest {
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            .init(name: "client", value: "gtx"),
            .init(name: "sl", value: source),
            .init(name: "tl", value: target),
            .init(name: "dt", value: "t"),    // the translation only, no dictionary
        ]
        var request = URLRequest(url: components.url!, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded;charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(("q=" + Self.formEncoded(text)).utf8)
        return request
    }

    /// Everything but unreserved ASCII percent-encoded, so `&`, `+`, `=` and newlines stay part of the text.
    static func formEncoded(_ text: String) -> String {
        let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return text.addingPercentEncoding(withAllowedCharacters: unreserved)!
    }

    /// The answer is bare nested arrays: `[[["Привет, мир. ", "Hello world. ", …], ["Как дела?", …]], null, "en", …]`.
    /// Google cuts the text into sentences; the translation is the first item of each, joined as is
    /// (spaces and newlines are inside the pieces). A piece without one (null) is skipped.
    static func decode(_ data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [Any],
              let sentences = json.first as? [Any] else { throw GoogleTranslateError.unreadable }
        return sentences.compactMap { ($0 as? [Any])?.first as? String }.joined()
    }
}

public enum GoogleTranslateError: LocalizedError, Equatable {
    case noSource
    case unreachable
    case tooManyRequests
    case http(Int)
    case unreadable

    public var errorDescription: String? {
        switch self {
        case .noSource:
            return "Google Translate needs the source language."
        case .unreachable:
            return "No answer from Google Translate. Is the Mac online?"
        case .tooManyRequests:
            return "Google Translate refuses requests from this address for now (too many). Try again later or pick another method."
        case .http(let status):
            return "Google Translate answered with HTTP \(status)."
        case .unreadable:
            return "Google Translate's answer could not be read: Google may have changed it."
        }
    }
}
