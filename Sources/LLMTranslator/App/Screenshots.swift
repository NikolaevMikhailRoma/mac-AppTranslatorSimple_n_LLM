import AppKit
import SwiftUI
import LLMTranslatorCore

/// `LLMTranslator --screenshots <folder>`: draws the Settings tabs and a translation popup into PNGs
/// for the README, in the light and the dark appearance (`-dark` suffix). Rendered offscreen, so no
/// Screen Recording permission is needed; default settings, so every run gives the same pictures.
@MainActor
enum Screenshots {
    static func render(to folder: URL) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        render(to: folder, appearance: .aqua, suffix: "")
        render(to: folder, appearance: .darkAqua, suffix: "-dark")
    }

    private static func render(to folder: URL, appearance name: NSAppearance.Name, suffix: String) {
        let appearance = NSAppearance(named: name)!
        // Window appearance alone is not enough: some AppKit controls (the tab bar) draw in the app's appearance.
        NSApp.appearance = appearance

        let suite = "LLMTranslator.screenshots"
        UserDefaults().removePersistentDomain(forName: suite)
        let store = SettingsStore(defaults: UserDefaults(suiteName: suite)!)

        let settings = SettingsWindowController(store: store)
        settings.window.appearance = appearance
        // Some controls only take the dark look once their window is on screen: show it beyond the screen edge.
        settings.window.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))
        settings.window.orderFrontRegardless()
        for (index, item) in settings.tabs.tabViewItems.enumerated() {
            settings.tabs.selectTabViewItem(at: index)
            settle()
            // The frame view includes the title bar; contentView alone would not.
            let frameView = settings.window.contentView!.superview!
            save(frameView, appearance: appearance, windowCorner: 10, to: folder.appendingPathComponent("settings-\(item.label.lowercased())\(suffix).png"))
        }

        settings.window.orderOut(nil)

        let model = BubbleModel(header: "ru → en",
                                source: "Привет! Спасибо за ответ.\nЗавтра пришлю файлы, а в четверг созвонимся.",
                                trims: false, growth: 1.2, maxSize: CGSize(width: 640, height: 600))
        model.append("Hi! Thanks for your reply.\nI'll send the files tomorrow, and we'll call on Thursday.")
        model.finish()
        let bubble = NSHostingView(rootView: TranslationBubble(model: model).padding(16))
        bubble.appearance = appearance
        bubble.frame = NSRect(origin: .zero, size: bubble.fittingSize)
        settle()
        save(bubble, appearance: appearance, to: folder.appendingPathComponent("popup\(suffix).png"))
    }

    /// Let SwiftUI and AppKit finish layout before drawing.
    private static func settle() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
    }

    /// - Parameter windowCorner: For a window: translucent parts (the tab bar) are see-through in the
    ///   bitmap, while on screen the window background shows through them. Lay that background under
    ///   the window, inside its rounded corners, so the PNG looks the same on any page colour.
    private static func save(_ view: NSView, appearance: NSAppearance, windowCorner: CGFloat? = nil, to url: URL) {
        view.layoutSubtreeIfNeeded()
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        appearance.performAsCurrentDrawingAppearance {
            view.cacheDisplay(in: view.bounds, to: rep)
        }
        var output = rep
        if let windowCorner, let flat = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: flat)
            NSGraphicsContext.current?.cgContext.clear(CGRect(x: 0, y: 0, width: flat.pixelsWide, height: flat.pixelsHigh))
            appearance.performAsCurrentDrawingAppearance {
                NSColor.windowBackgroundColor.setFill()
                NSBezierPath(roundedRect: view.bounds, xRadius: windowCorner, yRadius: windowCorner).fill()
            }
            rep.draw(in: view.bounds, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            NSGraphicsContext.restoreGraphicsState()
            output = flat
        }
        guard let png = output.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: url)
        print("Saved \(url.path) (\(Int(view.bounds.width))×\(Int(view.bounds.height)) pt)")
    }
}
