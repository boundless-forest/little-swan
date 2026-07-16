# Release and Homebrew packaging

Little Swan is a macOS GUI app, so Homebrew distribution uses a Cask rather than a source Formula.

## Prerequisites

- A Developer ID Application certificate for `com.bearwang.littleswan`.
- App Store Connect API credentials with notarization access.
- A public GitHub repository with Releases enabled.
- Confirmed redistribution rights for every checked-in design asset.

The local `make app` target uses ad-hoc signing by default and is suitable only for development. Public artifacts must be Developer ID signed with Hardened Runtime and notarized by Apple.

## Local packaging

Create a native-architecture development archive:

```sh
make archive
```

Create, sign, notarize, staple, and archive a universal release after storing credentials with `xcrun notarytool store-credentials`:

```sh
make notarize \
  ARCHS="arm64 x86_64" \
  SIGNING_IDENTITY="Developer ID Application: Example (TEAMID)" \
  NOTARY_PROFILE="little-swan-notary"
```

The output is `dist/Little-Swan-<version>.zip`. `VERSION` is the source of the release version; `CFBundleShortVersionString` is set while assembling the app.

## Automated GitHub release

Configure these Actions secrets:

- `DEVELOPER_ID_APPLICATION_P12_BASE64`
- `DEVELOPER_ID_APPLICATION_P12_PASSWORD`
- `DEVELOPER_ID_APPLICATION_IDENTITY`
- `RELEASE_KEYCHAIN_PASSWORD`
- `APP_STORE_CONNECT_API_KEY_P8_BASE64`
- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`

Then update `VERSION`, update `CHANGELOG.md`, merge the release change, and push a matching tag such as `v0.1.0`. The release workflow tests the app, creates a universal binary, signs it with Hardened Runtime, submits it with `notarytool`, staples the ticket, creates the ZIP, renders a checksum-pinned Cask, and publishes both files to GitHub Releases.

## Homebrew Cask

`Packaging/Homebrew/little-swan.rb.template` is rendered with the release archive's SHA-256:

```sh
Scripts/render-homebrew-cask.sh 0.1.0 dist/Little-Swan-0.1.0.zip
```

The result is `dist/little-swan.rb`. Publish that file in a dedicated repository named `boundless-forest/homebrew-tap`, then users can install it with:

```sh
brew install --cask boundless-forest/tap/little-swan
```

Before publishing the Cask, run `brew style`, `brew audit --new --cask`, install it, launch the app, and uninstall it on both Apple Silicon and Intel macOS 14 or later. Submission to the official `homebrew/cask` repository can follow after the app has a stable release history and meets Homebrew's acceptance criteria.

## Release checklist

1. Confirm `swift run LittleSwanSmokeTests` and `swift build -c release` pass.
2. Confirm the copyright notice, asset provenance, privacy text, and security contact are ready for publication.
3. Confirm the tag exactly matches `VERSION`.
4. Verify the final app with `codesign --verify --deep --strict`, `spctl --assess --type execute`, and `xcrun stapler validate`.
5. Test a clean install from the GitHub release ZIP.
6. Render, audit, install, launch, and uninstall the Homebrew Cask.
