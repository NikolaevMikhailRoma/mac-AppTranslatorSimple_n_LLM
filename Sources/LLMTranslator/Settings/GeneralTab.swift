import SwiftUI
import LLMTranslatorCore

struct GeneralTab: View {
    @Bindable var store: SettingsStore

    var body: some View {
        VStack(spacing: 4) {
            FormRow(label: "Language 1") {
                Picker("", selection: $store.settings.language1) {
                    ForEach(Language.forLanguage1) { Text($0.displayName).tag($0.code) }
                }
                .labelsHidden()
                .frame(width: 180)
            }
            FormRow(label: "Language 2") {
                Picker("", selection: $store.settings.language2) {
                    ForEach(Language.forLanguage2) { Text($0.displayName).tag($0.code) }
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
