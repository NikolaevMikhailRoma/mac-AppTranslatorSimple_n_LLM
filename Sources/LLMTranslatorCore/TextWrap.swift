import Foundation

/// Word-wraps lines longer than `maxLength`; existing newlines are kept.
public enum TextWrap {
    public static func wrap(_ text: String, maxLength: Int?) -> String {
        guard let maxLength = maxLength, maxLength > 0 else {
            return text
        }

        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        var resultLines: [String] = []

        for line in lines {
            if line.count <= maxLength {
                resultLines.append(String(line))
                continue
            }

            var currentLine = ""
            let words = line.split(separator: " ")

            for word in words {
                if currentLine.isEmpty {
                    currentLine = String(word)
                } else if currentLine.count + 1 + word.count <= maxLength {
                    currentLine += " " + String(word)
                } else {
                    resultLines.append(currentLine)
                    currentLine = String(word)
                }
            }
            resultLines.append(currentLine)
        }

        return resultLines.joined(separator: "\n")
    }
}
