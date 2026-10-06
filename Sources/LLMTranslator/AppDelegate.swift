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
    /// The translation on screen; a new ⌘C C or closing the popup cancels it.
    private var currentTranslation: Task<Void, Never>?
    private var currentModel: BubbleModel?
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
        if let index = CommandLine.arguments.firstIndex(of: "--screenshots") {
            let folder = CommandLine.arguments.dropFirst(index + 1).first ?? "assets"
            Screenshots.render(to: URL(fileURLWithPath: folder))
            NSApp.terminate(nil)
            return
        }
        buildStatusItem()
        NSApp.mainMenu = AppMenu.make()

        // 1. Initialize services; the translation service is built per request from current settings
        clipboardService = ClipboardService { [store] in store.settings.developer.doubleCopyGapSeconds }
        focusService = FocusService()
        keyboardService = KeyboardService()
        popoverService = PopoverService(focusService: focusService, keyboardService: keyboardService)
        popoverService.onClose = { [weak self] closed in
            // Only the translation on screen; an older popup closing must not stop a newer request.
            if let self, closed != nil, closed === currentModel { currentTranslation?.cancel() }
        }

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
        clipboardService?.stopMonitoring()
    }

    // MARK: Event Handling
    private func handleDoubleCopy() {
        guard let copied = NSPasteboard.general.string(forType: .string), !copied.isEmpty else { return }
        let settings = store.settings
        let src = settings.joinBrokenLines ? LineJoiner.join(copied) : copied
        let translationService = TranslationService(
            provider: ProviderFactory.createProvider(for: settings, config: config),
            languageDetector: LanguageDetector(native: settings.nativeLanguage, second: settings.secondLanguage)
        )
        let (source, target, pieces) = translationService.stream(src, streaming: settings.developer.streamLLM)

        // The popup opens with the first word, sized by the original; until then only the icon shows the work.
        let screen = NSScreen.main?.visibleFrame.size ?? CGSize(width: 1440, height: 900)
        let model = BubbleModel(header: "\(source) → \(target)", source: src, trims: settings.trimTranslation,
                                growth: settings.developer.popupGrowth,
                                maxSize: CGSize(width: CGFloat(settings.developer.popupMaxWidth),
                                                height: screen.height * 0.6))
        currentTranslation?.cancel()
        currentModel = model

        runningRequests += 1
        currentTranslation = Task {
            defer { runningRequests -= 1 }
            let started = Date()
            do {
                for try await piece in pieces {
                    model.append(piece)
                    if !model.text.isEmpty && popoverService.shownModel !== model {
                        os_log("[AppDelegate] first piece after %d ms", Int(Date().timeIntervalSince(started) * 1000))
                        popoverService.show(model: model)
                    }
                }
                // A cancelled stream just ends; its half-written text must not reach the clipboard.
                guard !Task.isCancelled else { return }
                model.finish()
                if popoverService.shownModel !== model { popoverService.show(model: model) }
                popoverService.fitToContent()
                os_log("[AppDelegate] finished after %d ms, %d characters",
                       Int(Date().timeIntervalSince(started) * 1000), model.text.count)
                if settings.copyTranslation {
                    clipboardService.write(model.text)
                }
            } catch {
                guard !Task.isCancelled else { return }
                os_log("[AppDelegate] Translation failed: %@", type: .error, String(describing: error))
                model.fail(String(describing: error))
                if popoverService.shownModel !== model { popoverService.show(model: model) }
                popoverService.fitToContent()
            }
        }
    }

    // MARK: Status-bar menu
    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let btn = statusItem.button {
            btn.image = Self.idleIcon
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
        // The menu bar ignores contentTintColor on template images (it turns black),
        // so the busy state swaps in a coloured, non-template copy of the symbol.
        statusItem.button?.image = busy ? Self.busyIcon : Self.idleIcon
    }

    private static let idleIcon: NSImage? = {
        let image = NSImage(systemSymbolName: "translate", accessibilityDescription: "Translator")
        image?.isTemplate = true
        return image
    }()

    private static let busyIcon: NSImage? = {
        let image = NSImage(systemSymbolName: "translate", accessibilityDescription: "Translating")?
            .withSymbolConfiguration(.init(paletteColors: [.systemRed]))
        image?.isTemplate = false
        return image
    }()

    @objc private func openSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(store: store)
        }
        settingsWindow?.show()
    }

    @objc private func quit() { NSApp.terminate(nil) }
}