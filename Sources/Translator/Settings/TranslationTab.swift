import SwiftUI
import TranslatorCore

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
            case .localLLM: LocalLLMSettingsView(settings: $store.settings.localLLM,
                                                 language1: store.settings.language1,
                                                 language2: store.settings.language2)
            }
        }
    }
}
