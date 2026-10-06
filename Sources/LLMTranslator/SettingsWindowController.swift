import AppKit
import SwiftUI

/// Same layout as the camera and the pomodoro: an AppKit tab view on top,
/// captions on the left, controls on the right. Each tab's content is SwiftUI.
@MainActor
final class SettingsWindowController {
    let window: NSWindow

    /// Fits the tallest tab, so switching tabs never resizes the window.
    private static let size = NSSize(width: 620, height: 500)

    init(store: SettingsStore) {
        window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.isReleasedWhenClosed = false

        let tabs = NSTabView()
        tabs.addTabViewItem(Self.tab("General", GeneralTab(store: store)))
        tabs.addTabViewItem(Self.tab("Translation", TranslationTab(store: store)))
        tabs.addTabViewItem(Self.tab("Developer", DeveloperTab(store: store)))

        let container = NSView()
        container.addSubview(tabs)
        tabs.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tabs.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            tabs.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            tabs.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            tabs.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
        ])
        window.contentView = container
        window.center()
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private static func tab(_ label: String, _ content: some View) -> NSTabViewItem {
        let item = NSTabViewItem()
        item.label = label
        item.view = NSHostingView(rootView: content.padding(20).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top))
        return item
    }
}
