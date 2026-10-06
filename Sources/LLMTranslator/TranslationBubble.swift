import SwiftUI

struct TranslationBubble: View {
    /// The small grey line on top, e.g. "ru → en". Never copied.
    let header: String?
    let text: String
    /// Long lines wrap at this width on screen only, so selecting or copying gives the text without extra newlines.
    let width: CGFloat

    static let font = NSFont.systemFont(ofSize: 15)

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let header {
                Text(header)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Text(text)
                .font(Font(Self.font))
                .multilineTextAlignment(.leading)
                .textSelection(.enabled)
                .frame(width: width, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(.regularMaterial)              // «капля» macOS
        .cornerRadius(12)
    }

    /// As wide as the longest line, but no wider than `maxWidth`.
    static func width(for text: String, maxWidth: CGFloat) -> CGFloat {
        let widest = text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { (String($0) as NSString).size(withAttributes: [.font: font]).width }
            .max() ?? 0
        return min(ceil(widest) + 2, maxWidth)
    }
}
