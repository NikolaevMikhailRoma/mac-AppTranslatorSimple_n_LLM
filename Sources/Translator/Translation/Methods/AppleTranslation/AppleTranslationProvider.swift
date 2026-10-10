import AppKit
import SwiftUI
import Translation
import TranslatorCore

/// The translator built into macOS (the Translation framework): on device, offline once the
/// languages are downloaded. Answers in one piece.
final class AppleTranslationProvider: TranslationProvider {
    /// The source always comes from the app (`TranslationMethod.needsSource`): no detection, it
    /// guesses wrong on mixed text, and macOS translates only the downloaded pair anyway.
    func translate(text: String, from source: String?, to target: String) async throws -> String {
        guard let source else { throw AppleTranslationError.noSource }
        return try await AppleTranslationHost.translate(text, from: source, to: target)
    }
}

enum AppleTranslationError: LocalizedError {
    case noSource
    case notDownloaded(from: String, to: String)
    case unsupported(from: String, to: String)
    case timedOut

    var errorDescription: String? {
        switch self {
        case .noSource:
            return "macOS Translation needs the source language."
        case .notDownloaded(let from, let to):
            return "macOS has not downloaded \(name(from)) → \(name(to)) yet: Settings → Translation → macOS Translation."
        case .unsupported(let from, let to):
            return "macOS Translation does not translate \(name(from)) → \(name(to))."
        case .timedOut:
            return "macOS Translation did not answer."
        }
    }

    private func name(_ code: String) -> String { Language(code: code).displayName }
}

/// On macOS 15 a translation session exists only inside a SwiftUI view (`.translationTask`),
/// so requests go through a 1×1 view in a window kept beyond the screen edge.
@MainActor
enum AppleTranslationHost {
    private static let requests = Requests()
    private static var window: NSWindow?

    static func translate(_ text: String, from source: String, to target: String) async throws -> String {
        let from = Locale.Language(identifier: source), to = Locale.Language(identifier: target)

        // A pair that is not downloaded would wait forever for a download prompt nobody can see.
        switch await LanguageAvailability().status(from: from, to: to) {
        case .installed: break
        case .supported: throw AppleTranslationError.notDownloaded(from: source, to: target)
        case .unsupported: throw AppleTranslationError.unsupported(from: source, to: target)
        @unknown default: throw AppleTranslationError.unsupported(from: source, to: target)
        }

        showWindow()
        return try await withCheckedThrowingContinuation { continuation in
            requests.start(text, from: from, to: to, continuation: continuation)
        }
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
