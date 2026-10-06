import AppKit
import SwiftUI
import LLMTranslatorCore

/// `LLMTranslator --screenshots <folder>`: draws the Settings tabs and a translation popup into PNGs
/// for the README. Rendered offscreen, so no Screen Recording permission is needed; default
/// settings and the light appearance, so every run gives the same pictures.
@MainActor
enum Screenshots {
    static func render(to folder: URL) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let suite = "LLMTranslator.screenshots"
        UserDefaults().removePersistentDomain(forName: suite)
        let store = SettingsStore(defaults: UserDefaults(suiteName: suite)!)

        let settings = SettingsWindowController(store: store)
        settings.window.appearance = NSAppearance(named: .aqua)
        for (index, item) in settings.tabs.tabViewItems.enumerated() {
            settings.tabs.selectTabViewItem(at: index)
            settle()
            // The frame view includes the title bar; contentView alone would not.
            let frameView = settings.window.contentView!.superview!
            save(frameView, to: folder.appendingPathComponent("settings-\(item.label.lowercased()).png"))
        }

        let model = BubbleModel(header: "ru → en",
                                source: "Привет! Спасибо за ответ.\nЗавтра пришлю файлы, а в четверг созвонимся.",
                                trims: true, growth: 1.2, maxSize: CGSize(width: 640, height: 600))
        model.append("Hi! Thanks for your reply.\nI'll send the files tomorrow, and we'll call on Thursday.")
        model.finish()
        let bubble = NSHostingView(rootView: TranslationBubble(model: model).padding(16))
        bubble.appearance = NSAppearance(named: .aqua)
        bubble.frame = NSRect(origin: .zero, size: bubble.fittingSize)
        settle()
        save(bubble, to: folder.appendingPathComponent("popup.png"))
    }

    /// Let SwiftUI and AppKit finish layout before drawing.
    private static func settle() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
    }

    private static func save(_ view: NSView, to url: URL) {
        view.layoutSubtreeIfNeeded()
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: url)
        print("Saved \(url.path) (\(Int(view.bounds.width))×\(Int(view.bounds.height)) pt)")
    }
}
