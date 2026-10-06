# LLM Translation Pipeline

How a ⌘C C becomes a translation by a local LLM. Read this before changing the LLM path; the code is in `Sources/LLMTranslatorCore` (no AppKit, unit-tested) and `Sources/LLMTranslator/Translation`.

## Flow

1. **Trigger** — `ClipboardService` polls the pasteboard; two copies closer than the Developer interval (0.3 s) are ⌘C C. A copy made inside the popup counts too: copying a translation twice translates it back, on purpose.
2. **Prepare** — `TranslationPipeline.start`: join lines broken by PDF or e-mail (`LineJoiner`, General setting), then pick the direction (`LanguageDetector`): mostly Cyrillic → language 2, anything else → language 1.
3. **Request** — `LocalLLMProvider` → `OpenAIClient`, `POST {server}/chat/completions`:
   - system: the prompt from Settings with `{language1/language2}` replaced by the target code (`ru`, `en`); `Prompt.standard` is the default;
   - user: the text as is;
   - `temperature: 0`, `max_tokens` from Advanced (8192), `stream: true`, `model` only if set (empty = whatever the server has loaded).
4. **Stream** — server-sent events, one piece per `data:` line, until `[DONE]`. `StreamedText` collects them; the popup opens on the first non-empty piece and grows down as text arrives.
5. **Finish** — trim (only if the Advanced setting is on), fit the popup to the text, copy to the clipboard if General says so. A new ⌘C C or closing the popup cancels the request.

## Decisions (do not undo without a reason)

- **No source language in the prompt.** It is a guess for non-Cyrillic text, and the model sees the text anyway.
- **Language codes, not names**, in the prompt; the prompt is in English whatever the languages.
- **The model is never asked to pick the direction** — the app does (Cyrillic count). Asking the model did not work.
- **"Output ONLY the translation" stays.** Without it Qwen answers "Привет" with "Hello! How can I help you today?".
- **No `enable_thinking`.** Not honoured reliably; thinking is switched off in LM Studio's model settings instead. Reasoning models are not supported yet.
- **Streaming is on by default**; Developer → "Stream LLM answers" off sends `stream: false` and shows the answer in one piece.
- **Errors are sentences** (`OpenAIClientError`), shown in the popup instead of the translation.

## Tested with

Qwen 3.5 9B in LM Studio (thinking off in the model's settings), MacBook Pro M1 Max 64 GB: first word 0.1–0.5 s on a sentence, about 1 s on a long paragraph.

## Changing it

- Behaviour of the request: `Methods/LocalLLM/` (`LocalLLMProvider`, `OpenAIClient`, `Prompt`). A model that needs extra request fields gets them through `OpenAIClient.chatBody(extra:)`.
- Settings: `LocalLLMSettings` (stored under the key `host`; keep stored keys stable, `Settings.decode` reads old data over the defaults).
- Check: `swift test`, `./build.sh`, ⌘C C on a live model, `Scripts/screenshots.sh` when the popup or Settings change.
