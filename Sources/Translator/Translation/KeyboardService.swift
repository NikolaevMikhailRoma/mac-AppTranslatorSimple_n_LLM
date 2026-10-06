import AppKit

/// Keys pressed in the popup: ⌘C copies, Esc closes. A local monitor sees only the app's own
/// key events, so no Accessibility permission is needed.
@MainActor
final class KeyboardService {
    private var keyMonitor: Any?
    var onEscape: (() -> Void)?

    /// Starts monitoring for the Command+C key combination.
    ///
    /// If text is selected in the popover, it allows the standard copy action.
    /// Otherwise, it copies the entire provided text to the pasteboard.
    ///
    /// - Parameter popoverText: The full text to be copied if there is no selection, read at the
    ///   moment of ⌘C because the translation may still be streaming in.
    func startMonitoring(for popoverText: @escaping @MainActor () -> String) {
        // Ensure any previous monitor is removed before starting a new one.
        stopMonitoring()

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {    // Esc
                MainActor.assumeIsolated { self?.onEscape?() }
                return nil
            }
            // Check for Command + C
            if event.modifierFlags.contains(.command),
               event.charactersIgnoringModifiers?.lowercased() == "c" {

                // 1. Text selected in the popup: copy just that.
                if let textView = event.window?.firstResponder as? NSTextView, textView.selectedRange().length > 0 {
                    textView.copy(nil)
                    return nil // Event handled, consume it.
                }

                // 2. If no selection/responder, copy the entire text.
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(MainActor.assumeIsolated { popoverText() }, forType: .string)
                return nil // Event handled, consume it to prevent the system beep.
            }
            return event // Not our event, pass it on.
        }
    }

    /// Stops monitoring for keyboard events.
    func stopMonitoring() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
}