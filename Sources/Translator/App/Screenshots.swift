import AppKit
import SwiftUI
import TranslatorCore

/// `AppTranslatorSimple --screenshots <folder>`: draws the Settings tabs and a translation popup into PNGs
/// for the README, in the light and the dark appearance (`-dark` suffix). Rendered offscreen, so no
/// Screen Recording permission is needed; default settings, so every run gives the same pictures.
/// `--methods` is for checking the panels, not for the README: the Translation tab of every method too
/// (`settings-translation-<method>.png`), in the system appearance only.
@MainActor
enum Screenshots {
    static func render(to folder: URL, methods: Bool = false) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if methods {
            let dark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            render(to: folder, appearance: dark ? .darkAqua : .aqua, suffix: dark ? "-dark" : "", methods: true)
            return
        }
        render(to: folder, appearance: .aqua, suffix: "", methods: false)
        render(to: folder, appearance: .darkAqua, suffix: "-dark", methods: false)
    }

    private static func render(to folder: URL, appearance name: NSAppearance.Name, suffix: String, methods: Bool) {
        let appearance = NSAppearance(named: name)!
        // Window appearance alone is not enough: some AppKit controls (the tab bar) draw in the app's appearance.
        NSApp.appearance = appearance

        let suite = "AppTranslatorSimple.screenshots"
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
        if methods, let tab = settings.tabs.tabViewItems.first(where: { $0.label == "Translation" }) {
            settings.tabs.selectTabViewItem(tab)
            for method in TranslationMethod.offered {
                store.settings.method = method
                settle(for: 3)    // panels may ask their engine first: Claude Code answers in about 2 s
                save(settings.window.contentView!.superview!, appearance: appearance, windowCorner: 10,
                     to: folder.appendingPathComponent("settings-translation-\(method.rawValue)\(suffix).png"))
            }
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
    private static func settle(for seconds: TimeInterval = 0.3) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
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
