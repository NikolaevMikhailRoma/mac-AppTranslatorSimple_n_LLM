import SwiftUI
import LLMTranslatorCore

/// Caption on the left, control pushed to the right.
struct FormRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
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
            Text("Mostly Cyrillic text is translated into language 2, anything else into language 1. Language 1 is only Russian for now.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            FormRow(label: "Copy the translation to the clipboard") {
                Toggle("", isOn: $store.settings.copyTranslation)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
            }
            FormRow(label: "Trim spaces and newlines around the translation") {
                Toggle("", isOn: $store.settings.trimTranslation)
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
            case .host: HostForm(host: $store.settings.host)
            }
        }
    }
}

struct HostForm: View {
    @Binding var host: HostSettings

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
                Button("Reset") { host.prompt = HostSettings.defaultPrompt }
                    .disabled(host.prompt == HostSettings.defaultPrompt)
            }
            .padding(.top, 10)
            TextEditor(text: $host.prompt)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 90)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(nsColor: .separatorColor)))
            Text("{to} becomes the target language code, such as ru or en.")
                .font(.caption)
                .foregroundStyle(.secondary)

            SectionHeader(title: "Advanced")
            FormRow(label: "Max answer length, tokens") {
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
        }
        .task(id: host.baseURL) { await loadModels() }
    }

    private func loadModels() async {
        do {
            models = try await ModelList.fetch(from: host)
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
            FormRow(label: "⌘C C interval") {
                Slider(value: $store.settings.developer.doubleCopyGapSeconds,
                       in: DeveloperSettings.doubleCopyGapRange, step: 0.05)
                    .frame(width: 180)
                Text(String(format: "%.2f s", store.settings.developer.doubleCopyGapSeconds))
                    .monospacedDigit()
                    .frame(width: 52, alignment: .trailing)
            }
            FormRow(label: "Popup max width") {
                Stepper(value: $store.settings.developer.popupMaxWidth,
                        in: DeveloperSettings.popupMaxWidthRange, step: 40) {
                    Text("\(store.settings.developer.popupMaxWidth) pt").monospacedDigit()
                }
            }

            FormRow(label: "Red icon while translating") {
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
