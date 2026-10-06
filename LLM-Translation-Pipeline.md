# LLM Translation Pipeline

```
⌘C C ─ ClipboardService ─▶ TranslationPipeline ─▶ LocalLLMProvider ─▶ OpenAIClient ─▶ popup
       two copies < 0.3 s    LineJoiner           prompt + text        POST /chat/completions,
                             LanguageDetector     (target code only)   SSE pieces → StreamedText
```

Read before changing the LLM path. Logic: `Sources/TranslatorCore` (no AppKit, tested); screen: `Sources/Translator/Translation`.

- **Direction:** mostly Cyrillic → language 2, anything else → language 1. The app decides, not the model.
- **Prompt:** from Settings, `{language1/language2}` → target code (`ru`, `en`); English whatever the languages. No source language: it is a guess and the model sees the text.
- **Request:** `temperature 0`, `max_tokens` from Advanced (8192), `stream: true`, `model` only if set.
- **Popup:** opens on the first piece, grows down, fitted at the end. A new ⌘C C or closing it cancels the request.

Keep:
- "Output ONLY the translation" — without it Qwen answers "Привет" with "Hello! How can I help you today?".
- No `enable_thinking` — unreliable; thinking is off in LM Studio's model settings. Reasoning models are not supported yet.
- Stored settings key `host` for `LocalLLMSettings`; `Settings.decode` reads old data over the defaults.

Tested: Qwen 3.5 9B in LM Studio, MacBook Pro M1 Max 64 GB — first word 0.1–0.5 s, about 1 s on a long paragraph.

Check after a change: `swift test`, `./build.sh`, ⌘C C on a live model.
