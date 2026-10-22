import SwiftUI

struct TranslationBubble: View {
    let model: BubbleModel

    static let font = NSFont.systemFont(ofSize: 15)

    /// Overlay scrollers draw over the text and take no room; "always show" ones take this much.
    static var scrollerWidth: CGFloat {
        NSScroller.preferredScrollerStyle == .legacy
            ? NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.header)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            // The scroller gets its own room beside the text, so its appearance does not re-wrap the lines.
            StreamingTextView(text: model.text, scrolls: model.scrolls)
                .frame(width: model.size.width + (model.scrolls ? Self.scrollerWidth : 0), height: model.size.height)
        }
        .padding(12)
        .background(.regularMaterial)
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
    let scrolls: Bool

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
        // The popup is widened by the scroller as `scrolls` turns on, a hair before the text overflows;
        // a hidden scroller would hand that room to the text and re-wrap it.
        scroll.autohidesScrollers = !scrolls
        let current = storage.string
        guard current != text else { return }
        let attributes: [NSAttributedString.Key: Any] = [.font: TranslationBubble.font, .foregroundColor: NSColor.labelColor]
        if text.hasPrefix(current) {
            storage.append(NSAttributedString(string: String(text.dropFirst(current.count)), attributes: attributes))
        } else {
            storage.setAttributedString(NSAttributedString(string: text, attributes: attributes))
        }
        // No scrolling to the new text: it streams in faster than anyone reads.
    }
}
