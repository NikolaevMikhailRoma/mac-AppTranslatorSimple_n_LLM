# LLMTranslator

A minimal native macOS menu bar translator. Copy text twice (⌘C C) and the
translation pops up next to the cursor. No Dock icon, no main window.

## Features

- Popup at the cursor on ⌘C C. ⌘C inside the popup copies the translation.
- The translation direction is picked automatically: Russian → English,
  English → Russian.
- Privacy: no analytics, nothing is collected. Text goes only to the
  translation service you set up. Per-method privacy details: not implemented yet.
- On-device: with a local model the text never leaves your Mac (except when
  you point the app at a remote host).

## Translation methods

| Method | Status |
| --- | --- |
| Local LLM or your own host — any OpenAI-compatible Chat Completions API | ✅ |
| Google Translate API | not implemented |
| DeepL API | not implemented |
| Claude subscription | not implemented |
| macOS built-in Translation | not implemented |

The app talks to `http://127.0.0.1:1234` (LM Studio's default port). Choosing
the host and port in Settings is not implemented yet.

## Build from source (developers)

All the source is in this repo and safe to review — no third-party dependencies, only Apple's own frameworks.

Requirements:
- macOS 15+
- Xcode Command Line Tools (provides `swift`, `codesign`) — install with `xcode-select --install` if `swift --version` doesn't work yet
- An OpenAI-compatible server on port 1234 with a non-reasoning model loaded

```
git clone https://github.com/NikolaevMikhailRoma/mac-AppTranslatorSimple_n_LLM.git
cd mac-AppTranslatorSimple_n_LLM
./build.sh
open LLMTranslator.app
```

Run the unit tests with `swift test` (pure logic lives in the
`LLMTranslatorCore` target).

## Version history

0.0.3 is the third implementation; the first two were never released.

## License

MIT — use it however you like.
