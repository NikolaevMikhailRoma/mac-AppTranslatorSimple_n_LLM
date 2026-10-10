import SwiftUI
import TranslatorCore

/// Nothing to set up: only what the method is, where the text goes and its limits.
struct DeepLSettingsView: View {
    var body: some View {
        Text("DeepL through the free endpoint of its browser extension: no key, no account. The copied text goes to DeepL. Up to \(DeepLProvider.maxLength) characters at a time. Not an official API: it may stop working, and many translations in a row may be refused for a while.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
