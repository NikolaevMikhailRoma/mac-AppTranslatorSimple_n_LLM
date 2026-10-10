import SwiftUI
import TranslatorCore

struct LocalLLMSettingsView: View {
    @Binding var settings: LocalLLMSettings
    /// From General, to show what the placeholder becomes.
    let language1: String
    let language2: String

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
                Picker("", selection: $settings.model) {
                    Text("First on the server").tag("")
                    if !settings.model.isEmpty, !(models ?? []).contains(settings.model) {
                        Text("\(settings.model) (not on the server)").tag(settings.model)
                    }
                    ForEach(models ?? [], id: \.self) { id in Text(id).tag(id) }
                }
                .labelsHidden()
                .frame(width: 196)
                Button {
                    Task { await loadModels() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Ask the server for its models again")
            }
            Text(modelsError ?? "Any OpenAI-compatible server: LM Studio, Ollama, llama.cpp. The list is what the server offers; “First on the server” takes the top one.")
                .font(.caption)
                .foregroundStyle(modelsError == nil ? Color.secondary : Color.red)
                .fixedSize(horizontal: false, vertical: true)

            PromptEditor(prompt: $settings.prompt, language1: language1, language2: language2)

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
