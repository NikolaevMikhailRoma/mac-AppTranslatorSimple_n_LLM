import SwiftUI

/// Caption on the left, control pushed to the right.
struct FormRow<Content: View>: View {
    let label: String
    /// Shown by a small ? after the label: on click, and as a tooltip on hover.
    var help: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Text(label)
                if let help { HelpButton(text: help) }
            }
            Spacer(minLength: 12)
            content()
        }
        .frame(minHeight: 28)
    }
}

/// A tooltip alone comes only after a pause and the icon looks clickable, so a click opens the text too.
private struct HelpButton: View {
    let text: String
    @State private var shown = false

    var body: some View {
        Button { shown.toggle() } label: {
            Image(systemName: "questionmark.circle")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help(text)
        .popover(isPresented: $shown, arrowEdge: .bottom) {
            Text(text)
                .frame(width: 260, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
        }
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
