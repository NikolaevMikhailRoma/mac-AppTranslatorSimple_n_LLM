import AppKit

/// The menu bar icon and its menu. Red while a translation is running, if Settings allow it.
@MainActor
final class StatusItemController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let highlightsWhileBusy: () -> Bool
    private let openSettings: () -> Void

    var isBusy = false {
        didSet { updateIcon() }
    }

    init(highlightsWhileBusy: @escaping () -> Bool, openSettings: @escaping () -> Void) {
        self.highlightsWhileBusy = highlightsWhileBusy
        self.openSettings = openSettings
        super.init()

        item.button?.image = Self.idleIcon
        let menu = NSMenu()
        let settings = menu.addItem(withTitle: "Settings…", action: #selector(settingsChosen), keyEquivalent: ",")
        settings.target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
    }

    @objc private func settingsChosen() { openSettings() }

    private func updateIcon() {
        // The menu bar ignores contentTintColor on template images (it turns black),
        // so the busy state swaps in a coloured, non-template copy of the symbol.
        item.button?.image = isBusy && highlightsWhileBusy() ? Self.busyIcon : Self.idleIcon
    }

    /// Also drawn on the app icon by Scripts/generate-icon.swift.
    static let symbol = "translate"

    private static let idleIcon: NSImage? = {
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Translator")
        image?.isTemplate = true
        return image
    }()

    private static let busyIcon: NSImage? = {
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Translating")?
            .withSymbolConfiguration(.init(paletteColors: [.systemRed]))
        image?.isTemplate = false
        return image
    }()
}
