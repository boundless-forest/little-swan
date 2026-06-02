# ExpressBridge

ExpressBridge is a native macOS menu bar app for turning text from any language into natural English.

The first version supports DeepSeek as a bring-your-own-key writing engine and defaults to `deepseek-v4-flash`.

## Features

- Menu bar app with a compact Dock-aware floating writing panel.
- Any-language input with English-only output.
- Debounced real-time translation and rewriting.
- Style menu: Natural, Polite, Casual, Professional, Concise.
- One-click copy for the selected English result with inline feedback.
- Provider-ready settings page with configurable default writing style and panel width.
- DeepSeek API key stored in local app configuration.
- No translation history.

## Development

```sh
swift build
swift run ExpressBridgeSmokeTests
swift run ExpressBridge
```

## App Bundle

```sh
make app
open ExpressBridge.app
```

The app configuration is stored at:

```txt
~/Library/Application Support/ExpressBridge/config.json
```
