import SwiftUI
import LLMTranslatorCore
import os.log

/// A service to manage the translation popover window.
@MainActor
final class PopoverService: NSObject, NSPopoverDelegate {
    // MARK: Properties
    private let popover = NSPopover()
    private var anchorWin: NSWindow?

    // MARK: Dependencies
    private let focusService: FocusService
    private let keyboardService: KeyboardService

    // MARK: Lifecycle
    init(focusService: FocusService, keyboardService: KeyboardService) {
        self.focusService = focusService
        self.keyboardService = keyboardService
        super.init()

        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
    }

    /// Called with the model that was on screen when the popover closes, e.g. to stop a translation nobody will see.
    var onClose: ((BubbleModel?) -> Void)?
    private(set) var shownModel: BubbleModel?
    private var host: NSHostingController<TranslationBubble>?

    /// Shows the popover at the mouse; `model` keeps filling it after this returns.
    /// - Parameter model: The text to display, and what ⌘C copies when nothing is selected.
    func show(model: BubbleModel) {
        os_log("[PopoverService] will-show popover")

        // 1. Create a 1x1 anchor window at the mouse position.
        let pt = NSEvent.mouseLocation
        let frame = NSRect(x: pt.x, y: pt.y, width: 1, height: 1)

        if anchorWin == nil {
            anchorWin = NSWindow(
                contentRect: frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            anchorWin?.level = .statusBar
            anchorWin?.isOpaque = false
            anchorWin?.backgroundColor = .clear
            anchorWin?.ignoresMouseEvents = true
            anchorWin?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        } else {
            anchorWin?.setFrame(frame, display: false)
        }

        // 2. Save focus and activate the app to bring the popover to the front.
        focusService.saveCurrentFocus()
        NSApp.activate(ignoringOtherApps: true)

        // 3. Show the anchor window.
        anchorWin?.orderFront(nil)

        // 4. Set up the SwiftUI view and size the popover.
        let host = NSHostingController(rootView: TranslationBubble(model: model))
        // The popover follows the view's size: estimated while streaming, fitted when finished.
        host.sizingOptions = .preferredContentSize
        self.host = host
        shownModel = model
        host.view.layoutSubtreeIfNeeded()
        popover.contentViewController = host
        popover.contentSize = host.view.fittingSize

        // 5. Show the popover.
        popover.show(
            relativeTo: anchorWin!.contentView!.bounds,
            of: anchorWin!.contentView!,
            preferredEdge: .minY   // below the cursor, so growing height moves only the bottom edge
        )
        os_log("[PopoverService] did-show popover %.0fx%.0f", popover.contentSize.width, popover.contentSize.height)

        // 6. Start monitoring for Cmd+C.
        keyboardService.startMonitoring { model.text }
    }

    /// The popover resizes itself through `sizingOptions`; this only logs the result once SwiftUI has laid it out.
    func fitToContent() {
        let before = popover.contentSize
        DispatchQueue.main.async { [popover] in
            os_log("[PopoverService] fit %.0fx%.0f -> %.0fx%.0f", before.width, before.height,
                   popover.contentSize.width, popover.contentSize.height)
        }
    }

    // MARK: NSPopoverDelegate
    func popoverWillClose(_ notification: Notification) {
        os_log("[PopoverService] popover will close")
        anchorWin?.orderOut(nil)
        focusService.restorePreviousFocus()
        keyboardService.stopMonitoring()
        onClose?(shownModel)
        shownModel = nil
    }
}
