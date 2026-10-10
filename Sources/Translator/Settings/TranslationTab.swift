import SwiftUI
import TranslatorCore

/// The method in a menu, like the languages in General: the LLMs, then the rest. The selected
/// method's settings below.
struct TranslationTab: View {
    @Bindable var store: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FormRow(label: "Method") {
                Picker("", selection: $store.settings.method) {
                    Section("LLM") { items(TranslationMethod.offered.filter(\.isLLM)) }
                    Section("Other") { items(TranslationMethod.offered.filter { !$0.isLLM }) }
                }
                .labelsHidden()
                .frame(width: 230)
            }

            switch store.settings.method {
            case .localLLM: LocalLLMSettingsView(settings: $store.settings.localLLM,
                                                 language1: store.settings.language1,
                                                 language2: store.settings.language2)
            case .claude: ClaudeSettingsView(settings: $store.settings.claude,
                                             language1: store.settings.language1,
                                             language2: store.settings.language2)
            case .appleTranslation: AppleTranslationSettingsView(language1: store.settings.language1,
                                                                 language2: store.settings.language2)
            }
        }
    }

    private func items(_ methods: [TranslationMethod]) -> some View {
        ForEach(methods) { method in
            Label(method.title, systemImage: method.symbol).tag(method)
        }
    }
}
