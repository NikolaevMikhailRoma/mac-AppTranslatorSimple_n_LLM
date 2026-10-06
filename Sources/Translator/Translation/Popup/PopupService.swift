import SwiftUI

/// The translation popup: a panel that takes the keyboard without activating the app
/// (`.nonactivatingPanel`, the way Maccy and Easydict do it). After ⌘C C another app stays
/// active and macOS 14+ will not let a background app activate itself, so a popover would
/// get neither Esc nor ⌘C nor an outside click; the panel gets all three.
@MainActor
final class PopupService {
    private let panel = TranslationPanel()
    private let keyboard: KeyboardService
    private var host: NSHostingController<TranslationBubble>?
    private var sizeObservation: NSKeyValueObservation?

    /// Called with the model that was on screen when the popup closes, e.g. to stop a translation nobody will see.
    var onClose: ((BubbleModel?) -> Void)?
    private(set) var shownModel: BubbleModel?

    init(keyboard: KeyboardService) {
        self.keyboard = keyboard
        keyboard.onEscape = { [weak self] in self?.close() }
        panel.onResignKey = { [weak self] in self?.close() }    // a click anywhere else
    }

    /// Shows the popup under the mouse; `model` keeps filling it after this returns.
    func show(model: BubbleModel) {
        let host = NSHostingController(rootView: TranslationBubble(model: model))
        // The view's size follows the model: estimated while streaming, fitted when finished.
        host.sizingOptions = .preferredContentSize
        self.host = host
        shownModel = model
        panel.contentViewController = host

        let size = host.view.fittingSize
        panel.setFrame(frameUnderMouse(size: size), display: true)
        // Keep the top edge where it is, so growing text moves only the bottom.
        sizeObservation = host.observe(\.preferredContentSize, options: [.new]) { [weak self] _, change in
            guard let size = change.newValue else { return }
            MainActor.assumeIsolated { self?.resize(to: size) }
        }

        panel.makeKeyAndOrderFront(nil)
        keyboard.startMonitoring { model.text }
        log.info("did-show popup \(Int(size.width))x\(Int(size.height))")
    }

    /// The popup resizes itself as the view's size changes; this logs the end result.
    func fitToContent() {
        DispatchQueue.main.async { [panel] in
            log.info("fit \(Int(panel.frame.width))x\(Int(panel.frame.height))")
        }
    }

    func close() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        keyboard.stopMonitoring()
        sizeObservation = nil
        onClose?(shownModel)
        shownModel = nil
    }

    private func resize(to size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        var frame = panel.frame
        frame.origin.y += frame.height - size.height
        frame.size = size
        panel.setFrame(frame, display: true)
    }

    /// Centred under the mouse, kept on the screen the mouse is on.
    private func frameUnderMouse(size: CGSize) -> NSRect {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) }?.visibleFrame
            ?? NSScreen.main?.visibleFrame ?? .zero
        var origin = NSPoint(x: mouse.x - size.width / 2, y: mouse.y - 8 - size.height)
        origin.x = min(max(origin.x, screen.minX), screen.maxX - size.width)
        origin.y = max(origin.y, screen.minY)
        return NSRect(origin: origin, size: size)
    }
}

/// Borderless and transparent: the bubble draws its own rounded background.
final class TranslationPanel: NSPanel {
    var onResignKey: (() -> Void)?

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .statusBar
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    override var canBecomeKey: Bool { true }

    override func resignKey() {
        super.resignKey()
        onResignKey?()
    }
}
