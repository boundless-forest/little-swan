# Little Swan

Little Swan is a native macOS menu bar app for turning text from any language into natural English.

The first version supports DeepSeek as a bring-your-own-key writing engine and defaults to `deepseek-v4-flash`.

## Features

- Menu bar app with a compact Dock-aware floating writing panel.
- Any-language input with English-only output.
- Debounced real-time translation and rewriting.
- Style menu: Natural, Polite, Casual, Professional, Concise.
- One-click copy for the selected English result with inline feedback.
- Provider-ready settings page with configurable default writing style.
- Resizable main panel that remembers the user's preferred size.
- DeepSeek API key stored in local app configuration.
- No translation history.

## Development

```sh
swift build
swift run LittleSwanSmokeTests
swift run LittleSwan
```

Regenerate the app icon, `.icns`, and menu bar template icon from the checked-in Google Stitch reference:

```sh
make logo-assets
```

## App Bundle

```sh
make app
open "Little Swan.app"
```

The app configuration is stored at:

```txt
~/Library/Application Support/Little Swan/config.json
```
