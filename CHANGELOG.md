# Changelog

All notable changes, newest first. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.0.5] — 2026-10-10

### Added
- Claude subscription method: translates through Claude Code on this Mac with your Claude plan, no API key.
  Model and effort are picked from what Claude Code offers; Settings shows the setup steps when
  Claude Code is not installed or not signed in.
- macOS Translation method: the translator built into macOS, on this Mac and offline once the
  languages are downloaded (Settings → Translation).
- About window (menu bar icon → About) with links to what's new and the source; the version in Settings → General.

### Changed
- The method is picked from a menu in Settings → Translation, LLMs first.
- Local LLM: the model is picked from the server's list; "First on the server" by default, ↻ asks the server again.
- Thinking is turned off for reasoning models (`reasoning_effort: "none"`), so the translation starts sooner.
- The app is no longer in the App Sandbox (the Claude method needs Claude Code and its sign-in), so
  when updating from 0.0.4 the settings are reset to the defaults once.

### Fixed
- LM Studio with two models loaded and no model chosen no longer fails with HTTP 400: the first model
  on the server is used.
- A server error shows the server's own message, not only the HTTP status.

## [0.0.4] — 2026-10-07

### Added
- Settings window (menu bar icon → Settings…) with three tabs: General, Translation, Developer.
- Streaming: the popup opens with the first word and fills in as the model writes.
- Server URL, model (picked from the server's list), prompt and maximum answer length in Settings.
- Lines broken by a PDF or an e-mail are joined before translating; list items and sentence ends stay.
- Optional: the translation goes to the clipboard on its own.
- Text copied from a password manager (marked as concealed or transient on the clipboard) is not translated.
- App icon.

### Changed
- The popup is now a panel that takes the keyboard without switching apps: Esc closes it and ⌘C copies
  without clicking it first; a click anywhere else closes it. It has no arrow any more.
- The popup opens under the cursor, grows down and is cut to the text at the end; selecting or
  copying gives the text without extra line breaks, and a selection survives while text streams in.
- The prompt names only the target language (`{language1/language2}`); `enable_thinking` is no longer sent.
- Settings are kept by macOS; `settings.json` is gone.

### Fixed
- A readable message when the server is not running, instead of an error dump.
- ⌘C in the popup no longer copies the "ru → en" line.

## [0.0.3] — 2026-10-06

### Changed
- Moved from an Xcode project to SwiftPM: the app builds from a clone with `./build.sh`; unit tests added.

## [0.0.2] — 2026-04-27

### Changed
- Any OpenAI-compatible API instead of LM Studio only.

## [0.0.1] — 2025-09-17

### Added
- First prototype: ⌘C C translates EN↔RU with a local model in LM Studio (Xcode project, not buildable from the repo).

[0.0.5]: https://github.com/NikolaevMikhailRoma/mac-AppTranslatorSimple_n_LLM/compare/v0.0.4...v0.0.5
[0.0.4]: https://github.com/NikolaevMikhailRoma/mac-AppTranslatorSimple_n_LLM/compare/v0.0.3...v0.0.4
[0.0.3]: https://github.com/NikolaevMikhailRoma/mac-AppTranslatorSimple_n_LLM/compare/v0.0.2...v0.0.3
[0.0.2]: https://github.com/NikolaevMikhailRoma/mac-AppTranslatorSimple_n_LLM/compare/v0.0.1...v0.0.2
[0.0.1]: https://github.com/NikolaevMikhailRoma/mac-AppTranslatorSimple_n_LLM/releases/tag/v0.0.1
