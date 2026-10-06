import SwiftUI
import TranslatorCore

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
