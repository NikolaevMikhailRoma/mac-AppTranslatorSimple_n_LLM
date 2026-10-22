import SwiftUI
import TranslatorCore

/// Tuning a regular user never needs.
struct DeveloperTab: View {
    @Bindable var store: SettingsStore

    var body: some View {
        VStack(spacing: 4) {
            FormRow(label: "⌘C C interval", help: "Two copies within this time count as ⌘C C. Raise it if a slow double press is missed.") {
                Slider(value: $store.settings.developer.doubleCopyGapSeconds,
                       in: DeveloperSettings.doubleCopyGapRange, step: 0.05)
                    .frame(width: 180)
                Text(String(format: "%.2f s", store.settings.developer.doubleCopyGapSeconds))
                    .monospacedDigit()
                    .frame(width: 52, alignment: .trailing)
            }
            FormRow(label: "Popup max width", help: "The popup grows with the text up to this width.") {
                Stepper(value: $store.settings.developer.popupMaxWidth,
                        in: DeveloperSettings.popupMaxWidthRange, step: 40) {
                    Text("\(store.settings.developer.popupMaxWidth) pt").monospacedDigit()
                }
            }
            FormRow(label: "Popup max height", help: "The popup grows down to this share of the screen height. Longer text scrolls.") {
                Slider(value: $store.settings.developer.popupMaxHeightFraction,
                       in: DeveloperSettings.popupMaxHeightFractionRange, step: 0.05)
                    .frame(width: 180)
                Text(String(format: "%.0f%%", store.settings.developer.popupMaxHeightFraction * 100))
                    .monospacedDigit()
                    .frame(width: 52, alignment: .trailing)
            }

            FormRow(label: "Popup size × original", help: "The popup opens at the original's size times this, then fits the translation.") {
                Slider(value: $store.settings.developer.popupGrowth,
                       in: DeveloperSettings.popupGrowthRange, step: 0.1)
                    .frame(width: 180)
                Text(String(format: "%.1f", store.settings.developer.popupGrowth))
                    .monospacedDigit()
                    .frame(width: 52, alignment: .trailing)
            }
            FormRow(label: "Stream LLM answers", help: "On: the translation appears as the model writes. Off: all at once.") {
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
