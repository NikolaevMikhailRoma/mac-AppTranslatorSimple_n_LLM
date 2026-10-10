import AppKit
import SwiftUI

/// Same layout as the camera and the pomodoro: an AppKit tab view on top,
/// captions on the left, controls on the right. Each tab's content is SwiftUI.
/// Under the tabs, on every tab: About on the left, Quit on the right.
@MainActor
final class SettingsWindowController {
    let window: NSWindow
    let tabs = NSTabView()

    /// Fits the tallest tab, so switching tabs never resizes the window.
    private static let size = NSSize(width: 520, height: 576)

    init(store: SettingsStore) {
        window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.isReleasedWhenClosed = false

        tabs.addTabViewItem(Self.tab("General", GeneralTab(store: store)))
        tabs.addTabViewItem(Self.tab("Translation", TranslationTab(store: store)))
        tabs.addTabViewItem(Self.tab("Developer", DeveloperTab(store: store)))

        let footer = NSHostingView(rootView: HStack {
            Button("About \(appName)") { AboutPanel.show() }
            Spacer()
            Button("Quit \(appName)") { NSApp.terminate(nil) }
        })

        let container = NSView()
        container.addSubview(tabs)
        container.addSubview(footer)
        tabs.translatesAutoresizingMaskIntoConstraints = false
        footer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tabs.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            tabs.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            tabs.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            footer.topAnchor.constraint(equalTo: tabs.bottomAnchor, constant: 12),
            footer.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            footer.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            footer.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
        ])
        window.contentView = container
        window.center()
    }

    func show() {
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private static func tab(_ label: String, _ content: some View) -> NSTabViewItem {
        let item = NSTabViewItem()
        item.label = label
        item.view = NSHostingView(rootView: content.padding(20).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top))
        return item
    }
}
