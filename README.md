# Little Swan

Little Swan is a native macOS menu bar app for turning text from any language into natural English.

Little Swan supports DeepSeek, OpenAI, and OpenRouter as bring-your-own-key writing engines. DeepSeek remains the default provider.

## Features

- Menu bar app with a compact Dock-aware floating writing panel.
- Any-language input with English-only output.
- Switchable real-time or manual translation with Command-Return generation and optional automatic clipboard copying.
- Flat writing-style selector: Natural, Polite, Casual, Professional, Concise.
- Editable English output.
- Reviewable input-polish changes with explicit accept and reject actions.
- One-click copy for the selected English result with inline feedback.
- Separate provider settings for DeepSeek, OpenAI, and OpenRouter with editable base URLs, model identifiers, and connection testing.
- Five fixed numbered drafts.
- Resizable main panel that remembers the user's preferred size.
- Provider API key stored in local app configuration.
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

App configuration, including provider API keys, is stored at:

```txt
~/Library/Application Support/Little Swan/config.json
```
