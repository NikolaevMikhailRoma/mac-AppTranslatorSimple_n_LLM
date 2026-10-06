import AppKit

/// Only connects the parts: the clipboard watcher starts a translation, the translation drives
/// the popup and the menu bar icon. Each part lives in its own type.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = SettingsStore()
    private var clipboard: ClipboardService?
    private var translation: TranslationController?
    private var statusItem: StatusItemController?
    private var settingsWindow: SettingsWindowController?

    func applicationDidFinishLaunching(_: Notification) {
        if let index = CommandLine.arguments.firstIndex(of: "--screenshots") {
            let folder = CommandLine.arguments.dropFirst(index + 1).first ?? "assets"
            Screenshots.render(to: URL(fileURLWithPath: folder))
            NSApp.terminate(nil)
            return
        }
        NSApp.mainMenu = AppMenu.make()

        let store = store
        let clipboard = ClipboardService { store.settings.developer.doubleCopyGapSeconds }
        let popup = PopoverService(focusService: FocusService(), keyboardService: KeyboardService())
        let translation = TranslationController(store: store, clipboard: clipboard, popup: popup)
        let statusItem = StatusItemController(
            highlightsWhileBusy: { store.settings.developer.highlightIconWhileTranslating },
            openSettings: { [weak self] in self?.openSettings() }
        )

        translation.onBusyChange = { statusItem.isBusy = $0 }
        clipboard.onDoubleCopy = { translation.translateClipboard() }
        clipboard.startMonitoring()

        self.clipboard = clipboard
        self.translation = translation
        self.statusItem = statusItem
        log.info("Services are running")
    }

    func applicationWillTerminate(_: Notification) {
        clipboard?.stopMonitoring()
    }

    private func openSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(store: store)
        }
        settingsWindow?.show()
    }
}
