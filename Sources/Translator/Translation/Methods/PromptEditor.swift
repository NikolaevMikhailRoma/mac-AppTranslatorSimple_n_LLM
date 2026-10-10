import SwiftUI
import TranslatorCore

/// The system prompt of an LLM method: the editor, Reset, and what the placeholder becomes.
struct PromptEditor: View {
    @Binding var prompt: String
    /// From General, to show what the placeholder becomes.
    let language1: String
    let language2: String

    private func firstLine(_ target: String) -> String {
        Prompt.render(prompt, target: target).split(separator: "\n").first.map(String.init) ?? ""
    }

    var body: some View {
        HStack {
            Text("Prompt")
            Spacer()
            Button("Reset") { prompt = Prompt.standard }
                .disabled(prompt == Prompt.standard)
        }
        .padding(.top, 10)
        TextEditor(text: $prompt)
            .font(.system(.body, design: .monospaced))
            .frame(minHeight: 90)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(nsColor: .separatorColor)))
        if Prompt.namesLanguage(prompt) {
            Text("\(Prompt.placeholder) becomes the language code from General: \(language1) for most text, \(language2) for mostly Cyrillic text. The model gets, for example: “\(firstLine(language2))”")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text("The prompt has no \(Prompt.placeholder): the model is not told which language to translate into.")
                .font(.caption)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
