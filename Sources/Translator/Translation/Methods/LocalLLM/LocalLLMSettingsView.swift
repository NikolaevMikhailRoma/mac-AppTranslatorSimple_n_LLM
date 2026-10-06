import SwiftUI
import TranslatorCore

struct LocalLLMSettingsView: View {
    @Binding var settings: LocalLLMSettings
    /// From General, to show what the placeholder becomes.
    let language1: String
    let language2: String

    private func firstLine(_ target: String) -> String {
        Prompt.render(settings.prompt, target: target).split(separator: "\n").first.map(String.init) ?? ""
    }

    /// What the server answered on /v1/models; nil until asked.
    @State private var models: [String]?
    @State private var modelsError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            FormRow(label: "Server URL") {
                TextField("", text: $settings.baseURL, prompt: Text("http://127.0.0.1:1234/v1"))
                    .frame(width: 230)
            }
            FormRow(label: "Model") {
                TextField("", text: $settings.model, prompt: Text("Loaded on the server"))
                    .frame(width: 196)
                Menu {
                    Button("Loaded on the server") { settings.model = "" }
                    if let models, !models.isEmpty {
                        Divider()
                        ForEach(models, id: \.self) { id in Button(id) { settings.model = id } }
                    }
                } label: {
                    Image(systemName: "list.bullet")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Models the server offers")
            }
            Text(modelsError ?? "Any OpenAI-compatible server: LM Studio, Ollama, llama.cpp. Pick a model when the server has several loaded.")
                .font(.caption)
                .foregroundStyle(modelsError == nil ? Color.secondary : Color.red)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text("Prompt")
                Spacer()
                Button("Reset") { settings.prompt = Prompt.standard }
                    .disabled(settings.prompt == Prompt.standard)
            }
            .padding(.top, 10)
            TextEditor(text: $settings.prompt)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 90)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(nsColor: .separatorColor)))
            if Prompt.namesLanguage(settings.prompt) {
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

            SectionHeader(title: "Advanced")
            FormRow(label: "Max answer length, tokens", help: "The longest translation the model may write. A token is about ¾ of an English word or half a Russian one. The arrows step by powers of two; any number can be typed.") {
                TextField("", value: Binding(
                    get: { settings.maxTokens },
                    set: { settings.maxTokens = min(max($0, LocalLLMSettings.maxTokensRange.lowerBound),
                                                LocalLLMSettings.maxTokensRange.upperBound) }
                ), format: .number.grouping(.never))
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .frame(width: 80)
                Stepper("") {
                    settings.maxTokens = LocalLLMSettings.nextMaxTokens(after: settings.maxTokens, up: true)
                } onDecrement: {
                    settings.maxTokens = LocalLLMSettings.nextMaxTokens(after: settings.maxTokens, up: false)
                }
                .labelsHidden()
            }
            FormRow(label: "Trim spaces and newlines around the answer",
                    help: "Remove spaces and empty lines the model puts before and after the translation. Off by default: current models rarely add them.") {
                Toggle("", isOn: $settings.trimAnswer)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
            }
        }
        .task(id: settings.baseURL) { await loadModels() }
    }

    private func loadModels() async {
        do {
            models = try await OpenAIClient(baseURL: settings.baseURL).models()
            modelsError = nil
        } catch is CancellationError {
        } catch {
            models = nil
            modelsError = "No answer from the server at \(settings.baseURL)."
        }
    }
}
