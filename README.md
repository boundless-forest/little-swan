# Little Swan

Little Swan is a native macOS menu bar app for turning text from any language into natural English.

Little Swan supports DeepSeek, OpenAI, and OpenRouter as bring-your-own-key writing engines. DeepSeek remains the default provider.

Requires macOS 14 Sonoma or later.

## Features

- Menu bar app with a compact Dock-aware floating writing panel.
- Any-language input with English-only output.
- Switchable real-time or manual translation with Command-Return generation and optional automatic clipboard copying.
- Focused writing-style selector: Spoken English or Formal English.
- Editable English output.
- Reviewable input-polish changes with explicit accept and reject actions.
- One-click copy for the selected English result with inline feedback.
- Separate provider settings for DeepSeek, OpenAI, and OpenRouter with editable base URLs, model identifiers, and connection testing.
- Five fixed numbered drafts.
- Resizable main panel that remembers the user's preferred size and has a customizable reset shortcut.
- Provider API keys stored in the local app configuration.
- No translation history.

## Install

Install from the project Homebrew tap after the first release is published:

```sh
brew install --cask boundless-forest/tap/little-swan
```

You can also download the ZIP from the repository's Releases page, extract it, and move `Little Swan.app` to Applications.

Little Swan is ad-hoc signed and is not notarized by Apple. On first launch, macOS may block the app because the developer cannot be verified. After attempting to open it, go to **System Settings > Privacy & Security**, click **Open Anyway**, and confirm that you want to open Little Swan. Only bypass this warning when the archive came from this repository's official Releases page or Homebrew tap.

## Development

```sh
swift build
swift run LittleSwanSmokeTests
swift run LittleSwan
```

The project requires Swift 6.0 or later. See [CONTRIBUTING.md](CONTRIBUTING.md) for the current development and external-contribution policy.

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

- Provider API keys and preferences: `~/Library/Application Support/Little Swan/config.json`
- Five working drafts: `~/Library/Application Support/Little Swan/source-drafts.json`

Little Swan sends source text only to the provider selected by the user. See [PRIVACY.md](PRIVACY.md) for details.

## Distribution

Maintainer instructions for ad-hoc releases, optional Developer ID notarization, GitHub Releases, and the Homebrew Cask are in [Packaging/README.md](Packaging/README.md).

## Copyright and permissions

Copyright © 2026 Bear Wang. All rights reserved.

No license is currently granted to use, copy, modify, or distribute this source code. Making the repository publicly viewable does not make Little Swan open source. GitHub users retain only the viewing and forking permissions provided by GitHub's Terms of Service.
