import SwiftUI
import Observation

/// What the popup shows; filled piece by piece while the model writes.
@MainActor
@Observable
final class BubbleModel {
    /// The small grey line on top, e.g. "ru → en". Never copied.
    var header: String
    private(set) var text = ""
    private(set) var isFinished = false
    /// The text area: estimated from the original while streaming, fitted to the translation at the end.
    private(set) var size: CGSize
    @ObservationIgnored private let trims: Bool
    @ObservationIgnored private let maxSize: CGSize

    init(header: String, source: String, trims: Bool, growth: CGFloat, maxSize: CGSize) {
        self.header = header
        self.trims = trims
        self.maxSize = maxSize
        self.size = TranslationBubble.size(for: source, growth: growth, maxSize: maxSize)
    }

    func append(_ piece: String) {
        // Leading spaces and newlines would push the text down before the first word.
        text += trims && text.isEmpty ? String(piece.drop(while: \.isWhitespace)) : piece
        // Grow down instead of showing a scroller; never shrink while the text is still coming.
        let needed = TranslationBubble.height(of: text, width: size.width, maxHeight: maxSize.height)
        if needed > size.height { size.height = needed }
    }

    func finish() {
        if trims { text = text.trimmingCharacters(in: .whitespacesAndNewlines) }
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

struct TranslationBubble: View {
    let model: BubbleModel

    static let font = NSFont.systemFont(ofSize: 15)

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.header)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            StreamingTextView(text: model.text)
                .frame(width: model.size.width, height: model.size.height)
        }
        .padding(12)
        .background(.regularMaterial)              // «капля» macOS
        .cornerRadius(12)
    }

    /// Width: the original's widest line × `growth`, capped; height: the original's height at that width × `growth`.
    /// The original stands in for the translation before it arrives.
    static func size(for source: String, growth: CGFloat, maxSize: CGSize) -> CGSize {
        let widest = source.split(separator: "\n", omittingEmptySubsequences: false)
            .map { (String($0) as NSString).size(withAttributes: [.font: font]).width }
            .max() ?? 0
        let width = min(max(ceil(widest * growth) + 4, 120), maxSize.width)
        return CGSize(width: width, height: min(height(of: source, width: width, maxHeight: .infinity) * growth,
                                                maxSize.height))
    }

    /// The text's height when wrapped at `width`: at least one line, at most `maxHeight`.
    static func height(of text: String, width: CGFloat, maxHeight: CGFloat) -> CGFloat {
        let storage = NSTextStorage(string: text.isEmpty ? " " : text, attributes: [.font: font])
        let container = NSTextContainer(size: NSSize(width: width, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        let layout = NSLayoutManager()
        layout.addTextContainer(container)
        storage.addLayoutManager(layout)
        layout.ensureLayout(for: container)
        return min(ceil(layout.usedRect(for: container).height) + 2, maxHeight)
    }
}

/// An AppKit text view, because new pieces are appended to it: a selection made while the
/// translation is still streaming in stays put. Wraps on screen only, so copying adds no newlines.
private struct StreamingTextView: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        let view = scroll.documentView as! NSTextView
        view.isEditable = false
        view.isSelectable = true
        view.drawsBackground = false
        view.textContainerInset = .zero
        view.textContainer?.lineFragmentPadding = 0
        view.font = TranslationBubble.font
        view.textColor = .labelColor
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let view = scroll.documentView as? NSTextView, let storage = view.textStorage else { return }
        let current = storage.string
        guard current != text else { return }
        let attributes: [NSAttributedString.Key: Any] = [.font: TranslationBubble.font, .foregroundColor: NSColor.labelColor]
        if text.hasPrefix(current) {
            storage.append(NSAttributedString(string: String(text.dropFirst(current.count)), attributes: attributes))
        } else {
            storage.setAttributedString(NSAttributedString(string: text, attributes: attributes))
        }
        // Follow the new text only when the user is not selecting something.
        if view.selectedRange().length == 0 { view.scrollToEndOfDocument(nil) }
    }
}
