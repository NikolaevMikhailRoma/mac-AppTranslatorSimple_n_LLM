import SwiftUI

/// Nothing to set up: only what the method is and where the text goes.
struct GoogleTranslateSettingsView: View {
    var body: some View {
        Text("Google Translate through the free endpoint of its web page: no key, no account. The copied text goes to Google. Not an official API: many translations in a row may be refused for a while.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
