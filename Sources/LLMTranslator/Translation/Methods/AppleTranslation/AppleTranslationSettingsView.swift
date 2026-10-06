import SwiftUI
import Translation
import LLMTranslatorCore

/// Which language pairs macOS has downloaded, and a button to download the missing ones.
struct AppleTranslationSettingsView: View {
    let language1: String
    let language2: String

    @State private var availability = Availability()
    /// Set by the Download button: the system shows its own download sheet for this pair.
    @State private var download: TranslationSession.Configuration?

    private var pairs: [Availability.Pair] {
        [.init(from: language1, to: language2), .init(from: language2, to: language1)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("The translator built into macOS: on this Mac, no server, offline once the languages are downloaded. Other languages: System Settings → General → Language & Region → Translation Languages.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            SectionHeader(title: "Languages")
            ForEach(pairs, id: \.self) { pair in
                FormRow(label: "\(Language(code: pair.from).displayName) → \(Language(code: pair.to).displayName)") {
                    switch availability.statuses[pair] {
                    case .installed?:
                        Text("Downloaded").foregroundStyle(.secondary)
                    case .supported?:
                        Button("Download…") {
                            download = .init(source: Locale.Language(identifier: pair.from),
                                             target: Locale.Language(identifier: pair.to))
                        }
                    case .unsupported?:
                        Text("Not supported").foregroundStyle(.secondary)
                    default:
                        ProgressView().controlSize(.small)
                    }
                }
            }
        }
        .translationTask(download, action: Downloader(availability: availability, pairs: pairs).run)
        .task(id: pairs) { await availability.refresh(pairs) }
    }

    @MainActor
    @Observable
    final class Availability {
        struct Pair: Hashable, Sendable {
            let from: String
            let to: String
        }

        private(set) var statuses: [Pair: LanguageAvailability.Status] = [:]

        func refresh(_ pairs: [Pair]) async {
            let system = LanguageAvailability()
            for pair in pairs {
                statuses[pair] = await system.status(from: Locale.Language(identifier: pair.from),
                                                     to: Locale.Language(identifier: pair.to))
            }
        }
    }

    /// Uses the session off the main actor, like `AppleTranslationHost`, then re-reads the statuses.
    private final class Downloader: Sendable {
        let availability: Availability
        let pairs: [Availability.Pair]

        init(availability: Availability, pairs: [Availability.Pair]) {
            self.availability = availability
            self.pairs = pairs
        }

        func run(_ session: TranslationSession) async {
            try? await session.prepareTranslation()
            await availability.refresh(pairs)
        }
    }
}
