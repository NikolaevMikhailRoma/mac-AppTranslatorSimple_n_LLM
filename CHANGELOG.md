# Changelog

All notable changes, newest first. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.0.4] — 2026-10-07

### Added
- Settings window (menu bar icon → Settings…) with three tabs: General, Translation, Developer.
- Streaming: the popup opens with the first word and fills in as the model writes.
- Server URL, model (picked from the server's list), prompt and maximum answer length in Settings.
- Lines broken by a PDF or an e-mail are joined before translating; list items and sentence ends stay.
- Optional: the translation goes to the clipboard on its own.
- App icon.

### Changed
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

[0.0.4]: https://github.com/NikolaevMikhailRoma/mac-AppTranslatorSimple_n_LLM/compare/v0.0.3...v0.0.4
[0.0.3]: https://github.com/NikolaevMikhailRoma/mac-AppTranslatorSimple_n_LLM/compare/v0.0.2...v0.0.3
[0.0.2]: https://github.com/NikolaevMikhailRoma/mac-AppTranslatorSimple_n_LLM/compare/v0.0.1...v0.0.2
[0.0.1]: https://github.com/NikolaevMikhailRoma/mac-AppTranslatorSimple_n_LLM/releases/tag/v0.0.1
