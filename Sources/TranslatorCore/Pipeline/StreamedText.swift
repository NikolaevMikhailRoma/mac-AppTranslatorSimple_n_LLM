import Foundation

/// The translation as it arrives, piece by piece; optionally without spaces and newlines around it.
public struct StreamedText: Equatable, Sendable {
    public private(set) var text = ""
    private let trims: Bool

    public init(trims: Bool) {
        self.trims = trims
    }

    public mutating func append(_ piece: String) {
        // Leading spaces and newlines would push the text down before the first word.
        text += trims && text.isEmpty ? String(piece.drop(while: \.isWhitespace)) : piece
    }

    /// The end of the answer: only now are trailing spaces known to be trailing.
    public mutating func finish() {
        if trims { text = text.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}
