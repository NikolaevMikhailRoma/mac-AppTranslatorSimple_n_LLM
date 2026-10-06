import Foundation

/// The models an OpenAI-compatible server offers, for the Model menu in Settings.
public enum ModelList {
    public static func fetch(from host: HostSettings, session: URLSession = .shared) async throws -> [String] {
        guard let url = host.modelsURL else { throw URLError(.badURL) }
        var request = URLRequest(url: url, timeoutInterval: 5)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, _) = try await session.data(for: request)
        return try decode(data)
    }

    static func decode(_ data: Data) throws -> [String] {
        struct Model: Decodable { let id: String }
        struct Response: Decodable { let data: [Model] }
        return try JSONDecoder().decode(Response.self, from: data).data.map(\.id)
    }
}
