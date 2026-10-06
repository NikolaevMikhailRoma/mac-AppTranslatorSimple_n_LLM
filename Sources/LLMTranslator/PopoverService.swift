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

    /// Shows the popover with the provided text.
    /// - Parameters:
    ///   - header: A small grey line above the text, not copied.
    ///   - text: The text to display, and what ⌘C copies when nothing is selected.
    ///   - maxWidth: Wider text wraps on screen only.
    func show(header: String?, text: String, maxWidth: CGFloat) {
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
        let bubble = TranslationBubble(header: header, text: text,
                                       width: TranslationBubble.width(for: text, maxWidth: maxWidth))
        let host = NSHostingController(rootView: bubble)
        host.view.layoutSubtreeIfNeeded()
        popover.contentViewController = host
        popover.contentSize = host.view.fittingSize

        // 5. Show the popover.
        popover.show(
            relativeTo: anchorWin!.contentView!.bounds,
            of: anchorWin!.contentView!,
            preferredEdge: .maxY
        )
        os_log("[PopoverService] did-show popover")

        // 6. Start monitoring for Cmd+C.
        keyboardService.startMonitoring(for: text)
    }

    // MARK: NSPopoverDelegate
    func popoverWillClose(_ notification: Notification) {
        os_log("[PopoverService] popover will close")
        anchorWin?.orderOut(nil)
        focusService.restorePreviousFocus()
        keyboardService.stopMonitoring()
    }
}
