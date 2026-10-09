import Foundation

/// Claude Code, the `claude` command, run once per request. The answer is paid for by the
/// subscription Claude Code is signed in with; no API key is involved. Nothing of the user's
/// Claude Code setup reaches the request (CLAUDE.md, skills, tools, MCP servers), the system prompt
/// is ours, and the run is not saved to Claude Code's history.
public struct ClaudeCode: Sendable {
    public let executable: URL

    public init(executable: URL) {
        self.executable = executable
    }

    /// Where the installers put `claude`: the native installer, then Homebrew and npm.
    public static let searchPaths = ["~/.local/bin/claude", "/opt/homebrew/bin/claude", "/usr/local/bin/claude"]

    /// The path from Settings, or else the first of `searchPaths` that exists. An app started from
    /// Finder does not get the Terminal's PATH, so the shell is not asked.
    public static func find(_ configured: String) -> ClaudeCode? {
        let configured = configured.trimmingCharacters(in: .whitespacesAndNewlines)
        return (configured.isEmpty ? searchPaths : [configured]).lazy
            .map { URL(fileURLWithPath: NSString(string: $0).expandingTildeInPath) }
            .first { url in
                var isFolder: ObjCBool = false
                return FileManager.default.fileExists(atPath: url.path, isDirectory: &isFolder) && !isFolder.boolValue
                    && FileManager.default.isExecutableFile(atPath: url.path)
            }
            .map(ClaudeCode.init(executable:))
    }

    // MARK: Requests

    /// The translation in pieces as Claude writes it. Cancelling the task that reads the stream
    /// stops Claude Code.
    public func translate(_ text: String, systemPrompt: String, model: String, effort: String) -> AsyncThrowingStream<String, Error> {
        let arguments = Self.translationArguments(systemPrompt: systemPrompt, model: model, effort: effort)
        return AsyncThrowingStream { continuation in
            let process = ClaudeProcess(executable: executable, arguments: arguments)
            let task = Task {
                defer { process.stop() }
                do {
                    try process.start(input: text)
                    var answer = ClaudeAnswer()
                    for await line in process.output {
                        switch try answer.read(line) {
                        case .piece(let piece)?:
                            continuation.yield(piece)
                        case .done(let rest)?:
                            if let rest { continuation.yield(rest) }
                            continuation.finish()
                            return
                        case nil:
                            continue
                        }
                    }
                    try await process.checkExit()
                    throw ClaudeCodeError.emptyAnswer
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
                process.stop()
            }
        }
    }

    /// The version, the account and the models, as Claude Code tells its SDK clients. Asks no model.
    public func info() async throws -> ClaudeCodeInfo {
        let process = ClaudeProcess(executable: executable, arguments: Self.infoArguments)
        defer { process.stop() }
        return try await withTaskCancellationHandler {
            try process.start(input: Self.infoRequest)
            for await line in process.output {
                if let info = ClaudeCodeInfo.decode(line) { return info }
            }
            try await process.checkExit()
            throw ClaudeCodeError.noInfo
        } onCancel: {
            process.stop()
        }
    }

    /// Turns off everything a session would bring along, for every run.
    static let isolation = ["--safe-mode", "--tools", "", "--setting-sources", "", "--strict-mcp-config",
                            "--no-session-persistence"]

    static func translationArguments(systemPrompt: String, model: String, effort: String) -> [String] {
        var arguments = ["-p", "--output-format", "stream-json", "--verbose", "--include-partial-messages",
                         "--system-prompt", systemPrompt] + isolation
        let model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        if !model.isEmpty { arguments += ["--model", model] }
        if !effort.isEmpty { arguments += ["--effort", effort] }
        return arguments
    }

    static let infoArguments = ["-p", "--input-format", "stream-json", "--output-format", "stream-json",
                                "--verbose"] + isolation
    static let infoRequest = #"{"type":"control_request","request_id":"info","request":{"subtype":"initialize"}}"# + "\n"

    /// The app's environment without an API key: Claude Code would bill a key it finds there
    /// instead of the subscription.
    static func environment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["ANTHROPIC_API_KEY"] = nil
        return environment
    }
}

/// One `claude` process. Foundation's `Process` is not `Sendable`; this wrapper starts it once,
/// then only reads its pipes and may stop it, which `Process` allows from any thread.
private final class ClaudeProcess: @unchecked Sendable {
    private let process = Process()
    private let stdin = Pipe()
    /// stdout line by line as it arrives.
    let output: AsyncStream<String>
    /// Only the last line of stderr is kept: usually the reason Claude Code stopped.
    private let errors: AsyncStream<String>
    private let exit: AsyncStream<Int32>

    init(executable: URL, arguments: [String]) {
        let stdout = Pipe(), stderr = Pipe()
        process.executableURL = executable
        process.arguments = arguments
        // Not a project folder: no project settings or CLAUDE.md to pick up.
        process.currentDirectoryURL = FileManager.default.temporaryDirectory
        process.environment = ClaudeCode.environment()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr
        output = Self.lines(of: stdout.fileHandleForReading, buffering: .unbounded)
        errors = Self.lines(of: stderr.fileHandleForReading, buffering: .bufferingNewest(1))
        let process = process
        exit = AsyncStream { continuation in
            process.terminationHandler = { continuation.yield($0.terminationStatus); continuation.finish() }
        }
    }

    func start(input: String) throws {
        do {
            try process.run()
        } catch {
            throw ClaudeCodeError.cannotRun(process.executableURL?.path ?? "claude")
        }
        let inputHandle = stdin.fileHandleForWriting
        // A process that died early must not take the app down with SIGPIPE.
        _ = fcntl(inputHandle.fileDescriptor, F_SETNOSIGPIPE, 1)
        try? inputHandle.write(contentsOf: Data(input.utf8))
        try? inputHandle.close()
    }

    /// Waits for the end; a non-zero exit is an error with stderr's last line.
    func checkExit() async throws {
        var status = Int32(0)
        for await code in exit { status = code }
        guard status != 0 else { return }
        var message = ""
        for await line in errors { message = line }
        throw ClaudeCodeError.exited(status: status, message: message)
    }

    func stop() {
        if process.isRunning { process.terminate() }
    }

    /// A pipe's text in lines, without empty ones. Read with a readability handler, not
    /// `FileHandle.bytes`: that one hands over a pipe's data only when the pipe closes.
    private static func lines(of handle: FileHandle,
                              buffering: AsyncStream<String>.Continuation.BufferingPolicy) -> AsyncStream<String> {
        let (lines, continuation) = AsyncStream.makeStream(of: String.self, bufferingPolicy: buffering)
        let splitter = LineSplitter()
        handle.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {    // the end of the output
                handle.readabilityHandler = nil
                if let rest = splitter.rest() { continuation.yield(rest) }
                continuation.finish()
            } else {
                splitter.add(data).forEach { continuation.yield($0) }
            }
        }
        return lines
    }
}

/// Cuts chunks of output into lines. Used by one readability handler, which runs one call at a time.
private final class LineSplitter: @unchecked Sendable {
    private var buffer = Data()

    func add(_ data: Data) -> [String] {
        buffer.append(data)
        var lines: [String] = []
        while let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) {
            let line = String(decoding: buffer[buffer.startIndex..<newline], as: UTF8.self)
            buffer.removeSubrange(buffer.startIndex...newline)
            if !line.isEmpty { lines.append(line) }
        }
        return lines
    }

    /// What is left after the last newline.
    func rest() -> String? {
        defer { buffer = Data() }
        return buffer.isEmpty ? nil : String(decoding: buffer, as: UTF8.self)
    }
}

/// Reads Claude Code's `stream-json` output: text pieces from the partial messages, then a result
/// that ends the answer or says what went wrong.
struct ClaudeAnswer {
    enum Step: Equatable {
        case piece(String)
        /// The end; carries the whole answer when no pieces came before it.
        case done(String?)
    }

    /// The error code of the last failed API call (`authentication_failed`, `rate_limit`…).
    private var errorCode: String?
    private var wrote = false

    mutating func read(_ line: String) throws -> Step? {
        guard let line = try? JSONDecoder().decode(Line.self, from: Data(line.utf8)) else { return nil }
        switch line.type {
        case "stream_event":
            guard line.event?.type == "content_block_delta", line.event?.delta?.type == "text_delta",
                  let text = line.event?.delta?.text, !text.isEmpty else { return nil }
            wrote = true
            return .piece(text)
        case "assistant":
            if let error = line.error { errorCode = error }
            return nil
        case "result":
            let result = line.result ?? ""
            if line.isError == true { throw ClaudeCodeError.failure(code: errorCode, message: result) }
            if wrote { return .done(nil) }
            // Without partial messages the whole answer comes only here.
            guard !result.isEmpty else { throw ClaudeCodeError.emptyAnswer }
            return .done(result)
        default:
            return nil
        }
    }

    private struct Line: Decodable {
        let type: String
        let event: Event?
        let error: String?
        let isError: Bool?
        let result: String?

        enum CodingKeys: String, CodingKey {
            case type, event, error, result
            case isError = "is_error"
        }

        struct Event: Decodable {
            let type: String
            let delta: Delta?
        }

        struct Delta: Decodable {
            let type: String
            let text: String?
        }
    }
}

/// What Claude Code says about itself before any request.
public struct ClaudeCodeInfo: Equatable, Sendable {
    public struct Model: Decodable, Equatable, Sendable, Identifiable {
        /// What `--model` takes: an alias such as `haiku` or a full name.
        public let value: String
        public let displayName: String
        public let description: String?
        /// Nil: the model takes no effort level.
        public let supportedEffortLevels: [String]?

        public var id: String { value }
    }

    public let version: String?
    public let models: [Model]
    public let signedIn: Bool
    /// "Claude Pro", "Claude Max"; nil when not signed in with a subscription.
    public let subscription: String?

    /// The answer to the `initialize` request; nil for any other line.
    static func decode(_ line: String) -> ClaudeCodeInfo? {
        struct Line: Decodable {
            let type: String
            let response: Response?
        }
        struct Response: Decodable {
            let response: Body?
        }
        struct Body: Decodable {
            let models: [Model]?
            let account: Account?
            let version: String?

            enum CodingKeys: String, CodingKey {
                case models, account
                case version = "claude_code_version"
            }
        }
        struct Account: Decodable {
            let email: String?
            let subscriptionType: String?
        }
        guard let line = try? JSONDecoder().decode(Line.self, from: Data(line.utf8)),
              line.type == "control_response", let body = line.response?.response else { return nil }
        let account = body.account
        return ClaudeCodeInfo(version: body.version, models: body.models ?? [],
                              signedIn: account?.email != nil || account?.subscriptionType != nil,
                              subscription: account?.subscriptionType)
    }
}

public enum ClaudeCodeError: LocalizedError, Equatable {
    /// The path from Settings; empty when `ClaudeCode.searchPaths` were searched.
    case notFound(String)
    case cannotRun(String)
    case notSignedIn
    /// Claude Code's own words: a usage limit, a model it does not know, no network.
    case failed(String)
    case exited(status: Int32, message: String)
    case emptyAnswer
    case noInfo

    static func failure(code: String?, message: String) -> ClaudeCodeError {
        code == "authentication_failed" ? .notSignedIn : .failed(message)
    }

    public var errorDescription: String? {
        switch self {
        case .notFound(""):
            return "Claude Code is not installed: no claude in ~/.local/bin, /opt/homebrew/bin or /usr/local/bin. How to install: Settings → Translation → Claude subscription."
        case .notFound(let path):
            return "No Claude Code at \(path). Check the path in Settings → Translation → Claude subscription."
        case .cannotRun(let path):
            return "Could not start Claude Code at \(path)."
        case .notSignedIn:
            return "Claude Code is not signed in. Open Terminal, run claude and sign in with your Claude account."
        case .failed(let message):
            return "Claude Code: \(message)"
        case .exited(let status, ""):
            return "Claude Code stopped with exit code \(status)."
        case .exited(let status, let message):
            return "Claude Code stopped with exit code \(status): \(message)"
        case .emptyAnswer:
            return "Claude sent an empty answer."
        case .noInfo:
            return "Claude Code did not list its models."
        }
    }
}
