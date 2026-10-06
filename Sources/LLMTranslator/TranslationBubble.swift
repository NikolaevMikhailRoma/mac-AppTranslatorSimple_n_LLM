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
    @ObservationIgnored private let trims: Bool

    init(header: String, trims: Bool) {
        self.header = header
        self.trims = trims
    }

    func append(_ piece: String) {
        // Leading spaces and newlines would push the text down before the first word.
        text += trims && text.isEmpty ? String(piece.drop(while: \.isWhitespace)) : piece
    }

    func finish() {
        if trims { text = text.trimmingCharacters(in: .whitespacesAndNewlines) }
        isFinished = true
    }

    func fail(_ message: String) {
        header = "Translation error"
        text = message
        isFinished = true
    }
}

struct TranslationBubble: View {
    let model: BubbleModel
    /// Estimated before the first word, so the popup does not jump while the text streams in.
    let size: CGSize

    static let font = NSFont.systemFont(ofSize: 15)

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.header)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            ScrollViewReader { proxy in
                ScrollView {
                    Group {
                        if model.text.isEmpty && !model.isFinished {
                            BlinkingCursor()
                        } else {
                            // Wraps on screen only: selecting or copying gives the text without extra newlines.
                            Text(model.text)
                                .font(Font(Self.font))
                                .textSelection(.enabled)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Color.clear.frame(height: 1).id("end")
                }
                .onChange(of: model.text) { proxy.scrollTo("end", anchor: .bottom) }
            }
            .frame(width: size.width, height: size.height)
        }
        .padding(12)
        .background(.regularMaterial)              // «капля» macOS
        .cornerRadius(12)
    }

    /// Width: the original's widest line × 1.2, capped. Height: the original's height at that width × 1.2.
    static func estimatedSize(for source: String, maxWidth: CGFloat, maxHeight: CGFloat) -> CGSize {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let widest = source.split(separator: "\n", omittingEmptySubsequences: false)
            .map { (String($0) as NSString).size(withAttributes: attributes).width }
            .max() ?? 0
        let width = min(max(ceil(widest * 1.2) + 4, 120), maxWidth)
        let height = (source as NSString).boundingRect(
            with: NSSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        ).height
        let line = ceil(font.ascender - font.descender + font.leading)
        return CGSize(width: width, height: min(max(ceil(height * 1.2), line), maxHeight))
    }
}

/// Shown until the first word arrives.
private struct BlinkingCursor: View {
    @State private var visible = true

    var body: some View {
        Text("▍")
            .font(Font(TranslationBubble.font))
            .foregroundStyle(.secondary)
            .opacity(visible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever()) { visible = false }
            }
    }
}
