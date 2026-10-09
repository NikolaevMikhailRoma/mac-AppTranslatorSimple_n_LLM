import XCTest
@testable import TranslatorCore

final class ClaudeAnswerTests: XCTestCase {
    /// Lines as Claude Code 2.1 writes them, shortened.
    static let delta = #"{"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Доброе"}}}"#
    static let thinking = #"{"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":"hm"}}}"#
    static let success = #"{"type":"result","subtype":"success","is_error":false,"result":"Доброе утро."}"#

    func testPiecesThenDone() throws {
        var answer = ClaudeAnswer()
        XCTAssertNil(try answer.read(#"{"type":"system","subtype":"init","model":"claude-haiku-5-5"}"#))
        XCTAssertNil(try answer.read(Self.thinking))
        XCTAssertEqual(try answer.read(Self.delta), .piece("Доброе"))
        XCTAssertNil(try answer.read(#"{"type":"assistant","message":{"content":[{"type":"text","text":"Доброе утро."}]}}"#))
        XCTAssertEqual(try answer.read(Self.success), .done(nil))
    }

    func testWholeAnswerInTheResultWhenNothingStreamed() throws {
        var answer = ClaudeAnswer()
        XCTAssertEqual(try answer.read(Self.success), .done("Доброе утро."))
    }

    func testNotJSONIsSkipped() throws {
        var answer = ClaudeAnswer()
        XCTAssertNil(try answer.read("[claude-code:unrecognized_model] {}"))
    }

    func testSignedOut() {
        var answer = ClaudeAnswer()
        XCTAssertNil(try answer.read(#"{"type":"assistant","error":"authentication_failed","is_api_error_message":true,"message":{"content":[{"type":"text","text":"Not logged in · Please run /login"}]}}"#))
        XCTAssertThrowsError(try answer.read(#"{"type":"result","subtype":"success","is_error":true,"result":"Not logged in · Please run /login"}"#)) {
            XCTAssertEqual($0 as? ClaudeCodeError, .notSignedIn)
        }
    }

    func testOtherErrorsKeepClaudeCodesWords() {
        var answer = ClaudeAnswer()
        _ = try? answer.read(#"{"type":"assistant","error":"model_not_found","message":{"content":[]}}"#)
        XCTAssertThrowsError(try answer.read(#"{"type":"result","is_error":true,"result":"There's an issue with the selected model (x)."}"#)) {
            XCTAssertEqual($0 as? ClaudeCodeError, .failed("There's an issue with the selected model (x)."))
        }
    }

    func testEmptyResult() {
        var answer = ClaudeAnswer()
        XCTAssertThrowsError(try answer.read(#"{"type":"result","is_error":false,"result":""}"#)) {
            XCTAssertEqual($0 as? ClaudeCodeError, .emptyAnswer)
        }
    }
}

final class ClaudeCodeInfoTests: XCTestCase {
    func testSignedIn() throws {
        let line = #"{"type":"control_response","response":{"subtype":"success","request_id":"info","response":{"claude_code_version":"2.1.296","models":[{"value":"haiku","resolvedModel":"claude-haiku-5-5","displayName":"Haiku 5.5","description":"Fastest for quick answers","supportsEffort":true,"supportedEffortLevels":["low","medium","high","xhigh","max"]},{"value":"claude-haiku-4-5-20251001","displayName":"Haiku 4.5","description":"Fastest for quick answers"}],"account":{"email":"a@b.c","subscriptionType":"Claude Pro","apiProvider":"firstParty"}}}}"#
        let info = try XCTUnwrap(ClaudeCodeInfo.decode(line))
        XCTAssertEqual(info.version, "2.1.296")
        XCTAssertTrue(info.signedIn)
        XCTAssertEqual(info.subscription, "Claude Pro")
        XCTAssertEqual(info.models.map(\.value), ["haiku", "claude-haiku-4-5-20251001"])
        XCTAssertEqual(info.models[0].supportedEffortLevels, ClaudeSettings.effortLevels)
        XCTAssertNil(info.models[1].supportedEffortLevels)
    }

    func testSignedOut() throws {
        let line = #"{"type":"control_response","response":{"subtype":"success","response":{"models":[],"account":{"tokenSource":"none","apiProvider":"firstParty"}}}}"#
        let info = try XCTUnwrap(ClaudeCodeInfo.decode(line))
        XCTAssertFalse(info.signedIn)
        XCTAssertNil(info.subscription)
    }

    func testOtherLines() {
        XCTAssertNil(ClaudeCodeInfo.decode(#"{"type":"system","subtype":"init"}"#))
        XCTAssertNil(ClaudeCodeInfo.decode("not json"))
    }
}

final class ClaudeCodeTests: XCTestCase {
    func testArguments() {
        let arguments = ClaudeCode.translationArguments(systemPrompt: "Translate to ru.", model: " haiku ", effort: "low")
        XCTAssertEqual(arguments.first, "-p")
        XCTAssertTrue(arguments.contains("--include-partial-messages"))
        XCTAssertTrue(arguments.contains("--safe-mode"))
        XCTAssertTrue(arguments.contains("--no-session-persistence"))
        XCTAssertEqual(Self.value(of: "--system-prompt", in: arguments), "Translate to ru.")
        XCTAssertEqual(Self.value(of: "--tools", in: arguments), "", "no tools")
        XCTAssertEqual(Self.value(of: "--model", in: arguments), "haiku")
        XCTAssertEqual(Self.value(of: "--effort", in: arguments), "low")
    }

    func testDefaultsAreLeftToClaudeCode() {
        let arguments = ClaudeCode.translationArguments(systemPrompt: "P", model: "", effort: "")
        XCTAssertFalse(arguments.contains("--model"))
        XCTAssertFalse(arguments.contains("--effort"))
    }

    /// The app started from a Claude Code session in a Dropbox folder.
    func testOnlyALoginEnvironmentReachesClaudeCode() {
        let environment = ClaudeCode.environment(from: [
            "HOME": "/Users/u", "TMPDIR": "/tmp/u/", "LANG": "en_US.UTF-8",
            "PWD": "/Users/u/Dropbox/projects", "CLAUDECODE": "1", "CLAUDE_CODE_CHILD_SESSION": "1",
            "ANTHROPIC_API_KEY": "sk-test", "PATH": "/Users/u/bin",
        ])
        XCTAssertEqual(environment["HOME"], "/Users/u")
        XCTAssertEqual(environment["LANG"], "en_US.UTF-8")
        XCTAssertNil(environment["CLAUDECODE"])
        XCTAssertNil(environment["CLAUDE_CODE_CHILD_SESSION"])
        XCTAssertNil(environment["ANTHROPIC_API_KEY"])
        XCTAssertFalse(environment["PWD"]!.contains("Dropbox"))
        XCTAssertFalse(environment["PATH"]!.contains("/Users/u/bin"))
    }

    func testFind() throws {
        let script = try FakeClaude.make("exit 0")
        XCTAssertEqual(ClaudeCode.find(" \(script.path) ")?.executable, script)
        XCTAssertNil(ClaudeCode.find("/no/such/claude"))
        XCTAssertNil(ClaudeCode.find(FileManager.default.temporaryDirectory.path), "a folder is not a command")
    }

    private static func value(of flag: String, in arguments: [String]) -> String? {
        arguments.firstIndex(of: flag).map { arguments[$0 + 1] }
    }
}

/// The provider against a shell script standing in for `claude`.
final class ClaudeProviderTests: XCTestCase {
    func testStreamsPiecesAndPassesTheTextOnStdin() async throws {
        // Echoes stdin back as the answer, in two pieces, the way Claude Code streams.
        let script = try FakeClaude.make("""
            text=$(cat)
            echo '{"type":"system","subtype":"init"}'
            echo '{"type":"stream_event","event":{"type":"content_block_delta","delta":{"type":"text_delta","text":"got: "}}}'
            echo "{\\"type\\":\\"stream_event\\",\\"event\\":{\\"type\\":\\"content_block_delta\\",\\"delta\\":{\\"type\\":\\"text_delta\\",\\"text\\":\\"$text\\"}}}"
            echo '{"type":"result","is_error":false,"result":"whole"}'
            """)
        let pieces = try await Self.pieces(script, text: "Hello")
        XCTAssertEqual(pieces, ["got: ", "Hello"])
    }

    func testNotSignedIn() async throws {
        let script = try FakeClaude.make("""
            cat > /dev/null
            echo '{"type":"assistant","error":"authentication_failed","message":{"content":[]}}'
            echo '{"type":"result","is_error":true,"result":"Not logged in · Please run /login"}'
            exit 1
            """)
        await Self.assertThrows(.notSignedIn, script)
    }

    func testCrashWithoutResultGivesTheLastStderrLine() async throws {
        let script = try FakeClaude.make("""
            cat > /dev/null
            echo 'starting' >&2
            echo 'Error: something broke' >&2
            exit 3
            """)
        await Self.assertThrows(.exited(status: 3, message: "Error: something broke"), script)
    }

    func testCleanExitWithoutAnswer() async throws {
        await Self.assertThrows(.emptyAnswer, try FakeClaude.make("cat > /dev/null"))
    }

    /// A process that never reads its input must not stop the app (SIGPIPE) or hang it.
    func testIgnoresStdin() async throws {
        let script = try FakeClaude.make(#"echo '{"type":"result","is_error":false,"result":"ok"}'"#)
        let pieces = try await Self.pieces(script, text: String(repeating: "long text ", count: 50_000))
        XCTAssertEqual(pieces, ["ok"])
    }

    func testMissingClaudeCode() async {
        var settings = ClaudeSettings()
        settings.executable = "/no/such/claude"
        do {
            _ = try await ClaudeProvider(settings: settings).translate(text: "x", from: nil, to: "ru")
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? ClaudeCodeError, .notFound("/no/such/claude"))
        }
    }

    /// Closing the popup cancels the stream; Claude Code must stop then, not run to the end.
    func testCancellingStopsClaudeCode() async throws {
        let marker = FileManager.default.temporaryDirectory.appendingPathComponent("claude-\(UUID().uuidString)")
        let script = try FakeClaude.make("""
            cat > /dev/null
            echo '{"type":"stream_event","event":{"type":"content_block_delta","delta":{"type":"text_delta","text":"first"}}}'
            sleep 3
            touch '\(marker.path)'
            """)
        var settings = ClaudeSettings()
        settings.executable = script.path
        let stream = ClaudeProvider(settings: settings).translateStream(text: "x", from: nil, to: "ru")
        let firstPiece = expectation(description: "first piece")
        // Like TranslationController: the task reading the stream is cancelled.
        let reader = Task {
            for try await piece in stream {
                XCTAssertEqual(piece, "first")
                firstPiece.fulfill()
            }
        }
        await fulfillment(of: [firstPiece], timeout: 2)
        reader.cancel()
        try await Task.sleep(for: .seconds(4))
        XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path), "the script was not stopped")
    }

    func testInfo() async throws {
        let script = try FakeClaude.make("""
            read request
            case "$request" in *initialize*) ;; *) exit 9 ;; esac
            echo '{"type":"control_response","response":{"response":{"claude_code_version":"9.9","models":[{"value":"haiku","displayName":"Haiku"}],"account":{"subscriptionType":"Claude Max"}}}}'
            sleep 3
            """)
        let started = Date()
        let info = try await ClaudeCode(executable: script).info()
        XCTAssertEqual(info.version, "9.9")
        XCTAssertEqual(info.subscription, "Claude Max")
        XCTAssertLessThan(Date().timeIntervalSince(started), 2, "does not wait for the process to end")
    }

    private static func pieces(_ script: URL, text: String) async throws -> [String] {
        var settings = ClaudeSettings()
        settings.executable = script.path
        var pieces: [String] = []
        for try await piece in ClaudeProvider(settings: settings).translateStream(text: text, from: nil, to: "ru") {
            pieces.append(piece)
        }
        return pieces
    }

    private static func assertThrows(_ expected: ClaudeCodeError, _ script: URL,
                                     file: StaticString = #filePath, line: UInt = #line) async {
        do {
            let pieces = try await pieces(script, text: "x")
            XCTFail("expected \(expected), got \(pieces)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? ClaudeCodeError, expected, file: file, line: line)
        }
    }
}

enum FakeClaude {
    /// An executable shell script in the temporary folder.
    static func make(_ body: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("fake-claude-\(UUID().uuidString)")
        try "#!/bin/sh\n\(body)\n".write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }
}

/// Against the real Claude Code on this Mac; uses the subscription. Run with `CLAUDE_LIVE=1 swift test`.
final class ClaudeLiveTests: XCTestCase {
    override func setUp() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["CLAUDE_LIVE"] == "1", "set CLAUDE_LIVE=1")
    }

    func testInfo() async throws {
        let claude = try XCTUnwrap(ClaudeCode.find(""))
        let info = try await claude.info()
        XCTAssertTrue(info.signedIn)
        XCTAssertTrue(info.models.contains { $0.value == "haiku" })
    }

    func testTranslates() async throws {
        var settings = ClaudeSettings()
        settings.effort = "low"
        var pieces: [String] = []
        for try await piece in ClaudeProvider(settings: settings).translateStream(text: "Good morning.", from: nil, to: "ru") {
            pieces.append(piece)
        }
        XCTAssertTrue(pieces.joined().contains("утро"), pieces.joined())
    }

    func testUnknownModel() async throws {
        var settings = ClaudeSettings()
        settings.model = "no-such-model"
        do {
            _ = try await ClaudeProvider(settings: settings).translate(text: "Hi", from: nil, to: "ru")
            XCTFail("expected an error")
        } catch let ClaudeCodeError.failed(message) {
            XCTAssertTrue(message.contains("no-such-model"), message)
        }
    }
}
