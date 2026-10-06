import Cocoa
import SwiftUI
import os.log
import Combine
import LLMTranslatorCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: UI
    private var statusItem: NSStatusItem!
    /// Requests still waiting for the model; a new ⌘C C can start before the last one ends.
    private var runningRequests = 0 {
        didSet { updateStatusIcon() }
    }

    // MARK: Settings
    private let store = SettingsStore()
    private let config = AppConfig.default
    private var settingsWindow: SettingsWindowController?

    // MARK: Services
    private var clipboardService: ClipboardService!
    private var popoverService: PopoverService!
    private var focusService: FocusService!
    private var keyboardService: KeyboardService!
    private var cancellables = Set<AnyCancellable>()

    // MARK: App lifecycle
    func applicationDidFinishLaunching(_: Notification) {
        buildStatusItem()
        NSApp.mainMenu = AppMenu.make()

        // 1. Initialize services; the translation service is built per request from current settings
        clipboardService = ClipboardService { [store] in store.settings.developer.doubleCopyGapSeconds }
        focusService = FocusService()
        keyboardService = KeyboardService()
        popoverService = PopoverService(focusService: focusService, keyboardService: keyboardService)

        // 2. Set up event handling
        clipboardService.doubleCopyPublisher
            .sink { [weak self] in
                self?.handleDoubleCopy()
            }
            .store(in: &cancellables)

        // 3. Start services
        clipboardService.startMonitoring()
        os_log("[AppDelegate] Services are running")
    }

    func applicationWillTerminate(_: Notification) {
        clipboardService.stopMonitoring()
    }

    // MARK: Event Handling
    private func handleDoubleCopy() {
        guard let src = NSPasteboard.general.string(forType: .string), !src.isEmpty else { return }
        let settings = store.settings
        let translationService = TranslationService(
            provider: ProviderFactory.createProvider(for: settings, config: config),
            languageDetector: LanguageDetector(native: settings.nativeLanguage, second: settings.secondLanguage)
        )
        runningRequests += 1
        Task {
            defer { runningRequests -= 1 }
            do {
                let tuple = try await translationService.translate(src)
                let prefix = "\(tuple.source) -> \(tuple.target)\n"
                await MainActor.run {
                    popoverService.show(text: prefix + tuple.result, maxLineLength: settings.developer.maxLineLength)
                }
            } catch {
                os_log("[AppDelegate] Translation failed: %@", type: .error, String(describing: error))
                // Optionally, show an error in the popover
                await MainActor.run {
                    popoverService.show(text: "Translation Error:\n\(String(describing: error))",
                                        maxLineLength: settings.developer.maxLineLength)
                }
            }
        }
    }

    // MARK: Status-bar menu
    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let btn = statusItem.button {
            btn.image = NSImage(systemSymbolName: "translate",
                                accessibilityDescription: "Translator")
            let menu = NSMenu()
            menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
            menu.addItem(.separator())
            menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q")
            statusItem.menu = menu
        }
    }

    /// Red while the model works, the usual menu bar colour otherwise.
    private func updateStatusIcon() {
        let busy = runningRequests > 0 && store.settings.developer.highlightIconWhileTranslating
        statusItem.button?.contentTintColor = busy ? .systemRed : nil
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(store: store)
        }
        settingsWindow?.show()
    }

    @objc private func quit() { NSApp.terminate(nil) }
}