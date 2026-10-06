import SwiftUI
import LLMTranslatorCore

/// Caption on the left, control pushed to the right.
struct FormRow<Content: View>: View {
    let label: String
    /// Shown as a tooltip on a small ⓘ after the label.
    var help: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Text(label)
                if let help {
                    Image(systemName: "questionmark.circle")
                        .foregroundStyle(.secondary)
                        .help(help)
                }
            }
            Spacer(minLength: 12)
            content()
        }
        .frame(minHeight: 28)
    }
}

/// Small grey capitals, centered, like APPLICATION in the camera and the pomodoro.
struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
            .padding(.bottom, 6)
    }
}

struct GeneralTab: View {
    @Bindable var store: SettingsStore

    var body: some View {
        VStack(spacing: 4) {
            FormRow(label: "Language 1") {
                Picker("", selection: $store.settings.nativeLanguage) {
                    ForEach(Language.native) { Text($0.displayName).tag($0.code) }
                }
                .labelsHidden()
                .frame(width: 180)
            }
            FormRow(label: "Language 2") {
                Picker("", selection: $store.settings.secondLanguage) {
                    ForEach(Language.second) { Text($0.displayName).tag($0.code) }
                }
                .labelsHidden()
                .frame(width: 180)
            }
            Text("Text is translated into language 1. If it is mostly Cyrillic, into language 2. Language 1 is only Russian for now.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            FormRow(label: "Join lines broken by PDF or e-mail", help: "Before translating, lines broken in the middle of a sentence are joined. Lines ending a sentence, blank lines and list items stay.") {
                Toggle("", isOn: $store.settings.joinBrokenLines)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
            }
            FormRow(label: "Copy the translation to the clipboard") {
                Toggle("", isOn: $store.settings.copyTranslation)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
            }

            SectionHeader(title: "Application")
            Button("Quit LLMTranslator") { NSApp.terminate(nil) }
        }
    }
}

/// The list of translation methods on top, the selected one's settings below.
struct TranslationTab: View {
    @Bindable var store: SettingsStore

    private static let rowHeight: CGFloat = 24

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            List(TranslationMethod.allCases, selection: Binding(
                get: { Optional(store.settings.method) },
                set: { if let method = $0 { store.settings.method = method } }
            )) { method in
                Label(method.title, systemImage: method.symbol)
                    .frame(height: Self.rowHeight)
                    .tag(method)
            }
            .listStyle(.bordered(alternatesRowBackgrounds: false))
            .frame(height: CGFloat(TranslationMethod.allCases.count) * (Self.rowHeight + 4) + 8)

            switch store.settings.method {
            case .host: HostForm(host: $store.settings.host,
                                 language1: store.settings.nativeLanguage,
                                 language2: store.settings.secondLanguage)
            }
        }
    }
}

struct HostForm: View {
    @Binding var host: HostSettings
    /// From General, to show what the placeholder becomes.
    let language1: String
    let language2: String

    private func firstLine(_ target: String) -> String {
        Prompt.render(host.prompt, target: target).split(separator: "\n").first.map(String.init) ?? ""
    }

    /// What the server answered on /v1/models; nil until asked.
    @State private var models: [String]?
    @State private var modelsError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            FormRow(label: "Server URL") {
                TextField("", text: $host.baseURL, prompt: Text("http://127.0.0.1:1234/v1"))
                    .frame(width: 230)
            }
            FormRow(label: "Model") {
                TextField("", text: $host.model, prompt: Text("Loaded on the server"))
                    .frame(width: 196)
                Menu {
                    Button("Loaded on the server") { host.model = "" }
                    if let models, !models.isEmpty {
                        Divider()
                        ForEach(models, id: \.self) { id in Button(id) { host.model = id } }
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
                Button("Reset") { host.prompt = Prompt.standard }
                    .disabled(host.prompt == Prompt.standard)
            }
            .padding(.top, 10)
            TextEditor(text: $host.prompt)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 90)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(nsColor: .separatorColor)))
            if Prompt.namesLanguage(host.prompt) {
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
                    get: { host.maxTokens },
                    set: { host.maxTokens = min(max($0, HostSettings.maxTokensRange.lowerBound),
                                                HostSettings.maxTokensRange.upperBound) }
                ), format: .number.grouping(.never))
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .frame(width: 80)
                Stepper("") {
                    host.maxTokens = HostSettings.nextMaxTokens(after: host.maxTokens, up: true)
                } onDecrement: {
                    host.maxTokens = HostSettings.nextMaxTokens(after: host.maxTokens, up: false)
                }
                .labelsHidden()
            }
            FormRow(label: "Trim spaces and newlines around the answer",
                    help: "Remove spaces and empty lines the model puts before and after the translation. Off by default: current models rarely add them.") {
                Toggle("", isOn: $host.trimAnswer)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
            }
        }
        .task(id: host.baseURL) { await loadModels() }
    }

    private func loadModels() async {
        do {
            models = try await OpenAIClient(baseURL: host.baseURL).models()
            modelsError = nil
        } catch is CancellationError {
        } catch {
            models = nil
            modelsError = "No answer from the server at \(host.baseURL)."
        }
    }
}

/// Tuning a regular user never needs.
struct DeveloperTab: View {
    @Bindable var store: SettingsStore

    var body: some View {
        VStack(spacing: 4) {
            FormRow(label: "⌘C C interval", help: "Two copies closer than this count as ⌘C C. Too short and a slow double press is missed; too long and two separate copies trigger a translation.") {
                Slider(value: $store.settings.developer.doubleCopyGapSeconds,
                       in: DeveloperSettings.doubleCopyGapRange, step: 0.05)
                    .frame(width: 180)
                Text(String(format: "%.2f s", store.settings.developer.doubleCopyGapSeconds))
                    .monospacedDigit()
                    .frame(width: 52, alignment: .trailing)
            }
            FormRow(label: "Popup max width", help: "The popup grows with the text up to this width, then wraps lines on screen. Copying never adds line breaks.") {
                Stepper(value: $store.settings.developer.popupMaxWidth,
                        in: DeveloperSettings.popupMaxWidthRange, step: 40) {
                    Text("\(store.settings.developer.popupMaxWidth) pt").monospacedDigit()
                }
            }

            FormRow(label: "Popup size × original", help: "Before the translation arrives, the popup is sized as the original text times this. If the translation is longer, the popup grows down; when it ends, empty space is cut.") {
                Slider(value: $store.settings.developer.popupGrowth,
                       in: DeveloperSettings.popupGrowthRange, step: 0.1)
                    .frame(width: 180)
                Text(String(format: "%.1f", store.settings.developer.popupGrowth))
                    .monospacedDigit()
                    .frame(width: 52, alignment: .trailing)
            }
            FormRow(label: "Stream LLM answers", help: "On: the popup opens with the first word and fills as the model writes. Off: it opens once the whole translation is ready.") {
                Toggle("", isOn: $store.settings.developer.streamLLM)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
            }
            FormRow(label: "Red icon while translating", help: "The menu bar icon turns red while a request to the model is running.") {
                Toggle("", isOn: $store.settings.developer.highlightIconWhileTranslating)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
            }

            SectionHeader(title: "Defaults")
            Button("Reset Developer Settings") { store.settings.developer = DeveloperSettings() }
                .disabled(store.settings.developer == DeveloperSettings())
        }
    }
}
