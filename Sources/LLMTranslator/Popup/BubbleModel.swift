import Foundation
import Observation
import LLMTranslatorCore

/// What the popup shows; filled piece by piece while the model writes.
@MainActor
@Observable
final class BubbleModel {
    /// The small grey line on top, e.g. "ru → en". Never copied.
    var header: String
    /// What is on screen, and what ⌘C copies when nothing is selected.
    private(set) var text = ""
    private(set) var isFinished = false
    /// The text area: estimated from the original while streaming, fitted to the translation at the end.
    private(set) var size: CGSize
    @ObservationIgnored private var answer: StreamedText
    @ObservationIgnored private let maxSize: CGSize

    init(header: String, source: String, trims: Bool, growth: CGFloat, maxSize: CGSize) {
        self.header = header
        self.answer = StreamedText(trims: trims)
        self.maxSize = maxSize
        self.size = TranslationBubble.size(for: source, growth: growth, maxSize: maxSize)
    }

    func append(_ piece: String) {
        answer.append(piece)
        text = answer.text
        // Grow down instead of showing a scroller; never shrink while the text is still coming.
        let needed = TranslationBubble.height(of: text, width: size.width, maxHeight: maxSize.height)
        if needed > size.height { size.height = needed }
    }

    func finish() {
        answer.finish()
        text = answer.text
        isFinished = true
        fitToText()
    }

    func fail(_ message: String) {
        header = "Translation error"
        text = message
        isFinished = true
        fitToText()
    }

    /// Cut the empty space below the text. The width stays, so the popup does not move sideways.
    private func fitToText() {
        size.height = TranslationBubble.height(of: text, width: size.width, maxHeight: maxSize.height)
    }
}
