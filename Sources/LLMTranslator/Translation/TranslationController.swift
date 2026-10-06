import AppKit
import LLMTranslatorCore

/// One ⌘C C from start to end: runs the pipeline, opens the popup with the first word, fills it,
/// copies the result if asked. A new ⌘C C or closing the popup cancels the translation on screen.
@MainActor
final class TranslationController {
    private let store: SettingsStore
    private let clipboard: ClipboardService
    private let popup: PopoverService

    /// True while at least one request is running; a new ⌘C C can start before the last one ends.
    var onBusyChange: ((Bool) -> Void)?
    private var running = 0 {
        didSet { onBusyChange?(running > 0) }
    }
    private var current: Task<Void, Never>?
    private var currentModel: BubbleModel?

    init(store: SettingsStore, clipboard: ClipboardService, popup: PopoverService) {
        self.store = store
        self.clipboard = clipboard
        self.popup = popup
        popup.onClose = { [weak self] closed in
            // Only the translation on screen; an older popup closing must not stop a newer request.
            if let self, closed != nil, closed === currentModel { current?.cancel() }
        }
    }

    func translateClipboard() {
        guard let copied = NSPasteboard.general.string(forType: .string), !copied.isEmpty else { return }
        let settings = store.settings
        let job = TranslationPipeline.start(copied, settings: settings)

        // The popup opens with the first word, sized by the original; until then only the icon shows the work.
        let screen = NSScreen.main?.visibleFrame.size ?? CGSize(width: 1440, height: 900)
        let model = BubbleModel(header: "\(job.source) → \(job.target)", source: job.text, trims: job.trimsAnswer,
                                growth: settings.developer.popupGrowth,
                                maxSize: CGSize(width: CGFloat(settings.developer.popupMaxWidth),
                                                height: screen.height * 0.6))
        current?.cancel()
        currentModel = model

        running += 1
        current = Task {
            defer { running -= 1 }
            let started = Date()
            do {
                for try await piece in job.pieces {
                    model.append(piece)
                    if !model.text.isEmpty && popup.shownModel !== model {
                        log.info("first piece after \(Self.milliseconds(since: started)) ms")
                        popup.show(model: model)
                    }
                }
                // A cancelled stream just ends; its half-written text must not reach the clipboard.
                guard !Task.isCancelled else { return }
                model.finish()
                showFinished(model)
                log.info("finished after \(Self.milliseconds(since: started)) ms, \(model.text.count) characters")
                if settings.copyTranslation {
                    clipboard.write(model.text)
                }
            } catch {
                guard !Task.isCancelled else { return }
                log.error("Translation failed: \(error.localizedDescription, privacy: .public)")
                model.fail(error.localizedDescription)
                showFinished(model)
            }
        }
    }

    /// A method without streaming, or an error, has not opened the popup yet.
    private func showFinished(_ model: BubbleModel) {
        if popup.shownModel !== model { popup.show(model: model) }
        popup.fitToContent()
    }

    private static func milliseconds(since start: Date) -> Int {
        Int(Date().timeIntervalSince(start) * 1000)
    }
}
