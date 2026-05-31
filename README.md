# Saywise

Saywise is a native macOS menu bar app for turning text from any language into natural English.

The first version supports DeepSeek as a bring-your-own-key writing engine and defaults to `deepseek-v4-flash`.

## Features

- Menu bar app with a floating always-on-top writing panel.
- Any-language input with English-only output.
- Debounced real-time translation and rewriting.
- Style switcher: Natural, Polite, Casual, Professional, Concise.
- One-click copy for the selected English result.
- Provider-ready settings page.
- DeepSeek API key stored in local app configuration.
- No translation history.

## Development

```sh
swift build
swift run SaywiseSmokeTests
swift run Saywise
```

## App Bundle

```sh
make app
open Saywise.app
```

The app configuration is stored at:

```txt
~/Library/Application Support/Saywise/config.json
```
