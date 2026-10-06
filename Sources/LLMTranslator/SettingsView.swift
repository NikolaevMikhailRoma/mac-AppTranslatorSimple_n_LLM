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

            SectionHeader(title: "Application")
            Button("Quit LLMTranslator") { NSApp.terminate(nil) }
        }
    }
}

/// The list of translation methods on the left, the selected one's settings on the right.
struct TranslationTab: View {
    @Bindable var store: SettingsStore

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            List(TranslationMethod.allCases, selection: Binding(
                get: { Optional(store.settings.method) },
                set: { if let method = $0 { store.settings.method = method } }
            )) { method in
                Text(method.title).tag(method)
            }
            .frame(width: 170)

            switch store.settings.method {
            case .host: HostForm(host: $store.settings.host)
            }
        }
    }
}

struct HostForm: View {
    @Binding var host: HostSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            FormRow(label: "Server URL") {
                TextField("", text: $host.baseURL, prompt: Text("http://127.0.0.1:1234/v1"))
                    .frame(width: 210)
            }
            FormRow(label: "Model") {
                TextField("", text: $host.model, prompt: Text("Loaded on the server"))
                    .frame(width: 210)
            }
            Text("Any OpenAI-compatible server: LM Studio, Ollama, llama.cpp.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Text("Prompt")
                Spacer()
                Button("Reset") { host.prompt = HostSettings.defaultPrompt }
                    .disabled(host.prompt == HostSettings.defaultPrompt)
            }
            .padding(.top, 12)
            TextEditor(text: $host.prompt)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 120)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(nsColor: .separatorColor)))
            Text("{from} and {to} become language codes, such as ru and en.")
                .font(.caption)
                .foregroundStyle(.secondary)
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
            FormRow(label: "Wrap lines longer than") {
                Stepper(value: $store.settings.developer.maxLineLength,
                        in: DeveloperSettings.maxLineLengthRange, step: 10) {
                    Text(store.settings.developer.maxLineLength == 0
                         ? "off" : "\(store.settings.developer.maxLineLength) chars")
                        .monospacedDigit()
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
