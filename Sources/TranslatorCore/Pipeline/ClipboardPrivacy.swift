import Foundation

/// Clipboard contents the app must not translate. Password managers mark what they copy with
/// these types (the convention of nspasteboard.org, which Maccy follows too).
public enum ClipboardPrivacy {
    public static let privateTypes: Set<String> = [
        "org.nspasteboard.ConcealedType",    // a password or another secret
        "org.nspasteboard.TransientType",    // there only for a moment, e.g. a one-time code
    ]

    public static func isPrivate(types: [String]) -> Bool {
        types.contains { privateTypes.contains($0) }
    }
}
