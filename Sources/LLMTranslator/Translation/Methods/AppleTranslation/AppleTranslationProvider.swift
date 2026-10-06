import AppKit
import NaturalLanguage
import SwiftUI
import Translation
import LLMTranslatorCore

/// The translator built into macOS (the Translation framework): on device, offline once the
/// languages are downloaded. Answers in one piece.
final class AppleTranslationProvider: TranslationProvider {
    func translate(text: String, from source: String?, to target: String) async throws -> String {
        try await AppleTranslationHost.translate(text, from: source, to: target)
    }
}

enum AppleTranslationError: LocalizedError {
    case unknownLanguage
    case notDownloaded(from: String, to: String)
    case unsupported(from: String, to: String)
    case timedOut

    var errorDescription: String? {
        switch self {
        case .unknownLanguage:
            return "macOS could not tell which language the text is in."
        case .notDownloaded(let from, let to):
            return "macOS has not downloaded the \(from) → \(to) languages yet: System Settings → General → Language & Region → Translation Languages."
        case .unsupported(let from, let to):
            return "macOS Translation does not translate \(from) → \(to)."
        case .timedOut:
            return "macOS Translation did not answer."
        }
    }
}

/// On macOS 15 a translation session exists only inside a SwiftUI view (`.translationTask`),
/// so requests go through a 1×1 view in a window kept beyond the screen edge.
@MainActor
enum AppleTranslationHost {
    private static let requests = Requests()
    private static var window: NSWindow?

    static func translate(_ text: String, from source: String?, to target: String) async throws -> String {
        guard let sourceCode = source ?? detectedLanguage(of: text) else { throw AppleTranslationError.unknownLanguage }
        let from = Locale.Language(identifier: sourceCode), to = Locale.Language(identifier: target)

        // A pair that is not downloaded would wait forever for a download prompt nobody can see.
        switch await LanguageAvailability().status(from: from, to: to) {
        case .installed: break
        case .supported: throw AppleTranslationError.notDownloaded(from: sourceCode, to: target)
        case .unsupported: throw AppleTranslationError.unsupported(from: sourceCode, to: target)
        @unknown default: throw AppleTranslationError.unsupported(from: sourceCode, to: target)
        }

        showWindow()
        return try await withCheckedThrowingContinuation { continuation in
            requests.start(text, from: from, to: to, continuation: continuation)
        }
    }

    /// The system's own guess, for when the app left the source open (non-Cyrillic text).
    static func detectedLanguage(of text: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage?.rawValue
    }

    private static func showWindow() {
        guard window == nil else { return }
        let window = NSWindow(contentRect: NSRect(x: -10_000, y: -10_000, width: 1, height: 1),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SessionView(requests: requests))
        window.orderFrontRegardless()
        self.window = window
    }

    /// One request at a time: a new ⌘C C replaces the one still waiting.
    @MainActor
    @Observable
    final class Requests {
        private(set) var configuration: TranslationSession.Configuration?
        @ObservationIgnored private var pending: (text: String, continuation: CheckedContinuation<String, Error>)?
        @ObservationIgnored private var timeout: Task<Void, Never>?

        func start(_ text: String, from: Locale.Language, to: Locale.Language,
                   continuation: CheckedContinuation<String, Error>) {
            finish(with: .failure(CancellationError()))
            pending = (text, continuation)
            if configuration?.source == from && configuration?.target == to {
                configuration?.invalidate()    // same pair: run the task again
            } else {
                configuration = .init(source: from, target: to)
            }
            timeout = Task { [weak self] in
                try? await Task.sleep(for: .seconds(20))
                guard !Task.isCancelled else { return }
                self?.finish(with: .failure(AppleTranslationError.timedOut))
            }
        }

        var pendingText: String? { pending?.text }

        func finish(with result: Result<String, Error>) {
            timeout?.cancel()
            pending?.continuation.resume(with: result)
            pending = nil
        }
    }

    private struct SessionView: View {
        let requests: Requests

        var body: some View {
            Color.clear
                .frame(width: 1, height: 1)
                .translationTask(requests.configuration, action: SessionRunner(requests: requests).run)
        }
    }

    /// Uses the session off the main actor, in the task the system hands it to;
    /// only the text and the result cross over.
    private final class SessionRunner: Sendable {
        let requests: Requests

        init(requests: Requests) {
            self.requests = requests
        }

        func run(_ session: TranslationSession) async {
            guard let text = await requests.pendingText else { return }
            do {
                let answer = try await session.translate(text).targetText
                await requests.finish(with: .success(answer))
            } catch {
                await requests.finish(with: .failure(error))
            }
        }
    }
}
