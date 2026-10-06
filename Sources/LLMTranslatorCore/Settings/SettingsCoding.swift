import Foundation

/// Reads stored settings over the current defaults: a key missing from the stored JSON (a setting
/// added in a newer version) keeps its default, and nothing else is lost. Structs stay plain
/// `Codable`, with no hand-written `init(from:)` to keep in sync with their fields.
enum SettingsCoding {
    static func decode<T: Codable>(_ type: T.Type, from data: Data, defaults: T) throws -> T {
        let base = try JSONSerialization.jsonObject(with: JSONEncoder().encode(defaults))
        let stored = try JSONSerialization.jsonObject(with: data)
        let merged = try JSONSerialization.data(withJSONObject: merge(stored, over: base))
        return try JSONDecoder().decode(T.self, from: merged)
    }

    /// Dictionaries merge key by key, all the way down; any other stored value replaces the default.
    static func merge(_ stored: Any, over base: Any) -> Any {
        guard let stored = stored as? [String: Any], var base = base as? [String: Any] else { return stored }
        for (key, value) in stored {
            base[key] = base[key].map { merge(value, over: $0) } ?? value
        }
        return base
    }
}
