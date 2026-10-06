import Foundation

/// Before translating: glue lines that were broken only by the layout (PDF, e-mail, terminal),
/// so the translator gets whole sentences. Blank lines between paragraphs and list items stay.
public enum LineJoiner {
    public static func join(_ text: String) -> String {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        var result = ""
        var previousWasText = false

        for rawLine in normalized.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                // A blank line ends the paragraph; keep it.
                result += "\n"
                if previousWasText { result += "\n" }
                previousWasText = false
                continue
            }

            if previousWasText && !startsListItem(trimmed) {
                if endsWithBrokenWord(result) {
                    // "экс-" + "порт" → "экспорт", but "Нью-" + "Йорк" → "Нью-Йорк".
                    if trimmed.first?.isLowercase == true { result.removeLast() }
                } else {
                    result += " "
                }
                result += trimmed
            } else {
                if previousWasText { result += "\n" }
                result += result.isEmpty || result.hasSuffix("\n") ? line.trimmingCharacters(in: .whitespaces) : trimmed
            }
            result = trimTrailingSpaces(result)
            previousWasText = true
        }
        return collapseBlankLines(result)
    }

    /// "- item", "• item", "* item", "1. item", "2) item".
    static func startsListItem(_ line: String) -> Bool {
        line.wholeMatch(of: /(?:[-•*–—]|\d{1,3}[.)])\s.*/) != nil
    }

    /// A letter followed by a hyphen at the very end: a word split across lines.
    private static func endsWithBrokenWord(_ text: String) -> Bool {
        guard text.hasSuffix("-"), text.count >= 2 else { return false }
        return text.dropLast().last?.isLetter == true
    }

    private static func trimTrailingSpaces(_ text: String) -> String {
        var text = text
        while text.hasSuffix(" ") { text.removeLast() }
        return text
    }

    /// Several blank lines in a row become one, and none are left at the ends.
    private static func collapseBlankLines(_ text: String) -> String {
        text.replacing(/\n{3,}/, with: "\n\n").trimmingCharacters(in: .newlines)
    }
}
