import AppKit
import TranslatorCore

/// A service that monitors the clipboard for double-copy gestures.
@MainActor
final class ClipboardService {
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var lastCopyTime: Date
    private let doubleCopyGap: () -> TimeInterval
    private var timer: Timer?

    /// Called on ⌘C C: two copies closer than the gap in Settings.
    var onDoubleCopy: (() -> Void)?

    /// - Parameter doubleCopyGap: Read on every copy, so a change in Settings applies at once.
    init(doubleCopyGap: @escaping () -> TimeInterval) {
        self.doubleCopyGap = doubleCopyGap
        self.lastChangeCount = pasteboard.changeCount
        self.lastCopyTime = Date()
    }

    /// Puts our own text on the clipboard without it counting as the user's copy.
    func write(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        lastChangeCount = pasteboard.changeCount
    }

    /// Starts monitoring the clipboard.
    func startMonitoring() {
        guard timer == nil else { return }
        timer = .scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            // The timer runs on the main run loop.
            MainActor.assumeIsolated { self?.pollClipboard() }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    /// Stops monitoring the clipboard.
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func pollClipboard() {
        guard pasteboard.changeCount != lastChangeCount else { return }

        // A password from a password manager: not a copy for translation, and it breaks a pair.
        if ClipboardPrivacy.isPrivate(types: pasteboard.types?.map(\.rawValue) ?? []) {
            lastChangeCount = pasteboard.changeCount
            lastCopyTime = .distantPast
            return
        }

        let now = Date()
        if now.timeIntervalSince(lastCopyTime) <= doubleCopyGap() {
            onDoubleCopy?()
        }

        lastCopyTime = now
        lastChangeCount = pasteboard.changeCount
    }
}