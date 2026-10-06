import SwiftUI

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
