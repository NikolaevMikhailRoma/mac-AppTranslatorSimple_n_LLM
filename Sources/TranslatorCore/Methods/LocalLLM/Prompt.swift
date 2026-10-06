import Foundation

/// The system prompt of the local LLM method: a template with the target language in it.
public enum Prompt {
    /// Replaced with the target language code from General, such as `ru` or `en`.
    public static let placeholder = "{language1/language2}"
    /// The placeholder's name before 0.0.4; still understood in prompts users wrote.
    static let oldPlaceholder = "{to}"

    public static let standard = """
        Translate to {language1/language2}.
        Preserve every character of formatting: spaces, newlines, tabs, punctuation, emojis, special symbols.
        Output ONLY the translation, nothing else.
        """

    /// Earlier standard prompts; a stored copy of one of them is upgraded to `standard`.
    static let earlierStandards = [
        """
        Translate from {from} to {to}.
        Preserve every character of formatting: spaces, newlines, tabs, punctuation, emojis, special symbols.
        Output ONLY the translation, nothing else.
        """,
        """
        Translate to {to}.
        Preserve every character of formatting: spaces, newlines, tabs, punctuation, emojis, special symbols.
        Output ONLY the translation, nothing else.
        """,
    ]

    /// The prompt as the model gets it.
    public static func render(_ template: String, target: String) -> String {
        template.replacingOccurrences(of: placeholder, with: target)
            .replacingOccurrences(of: oldPlaceholder, with: target)
    }

    /// Without the placeholder the model is not told which language to translate into.
    public static func namesLanguage(_ template: String) -> Bool {
        template.contains(placeholder) || template.contains(oldPlaceholder)
    }
}
