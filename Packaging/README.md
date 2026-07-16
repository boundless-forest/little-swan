# Release and Homebrew packaging

Little Swan is a macOS GUI app, so Homebrew distribution uses a Cask rather than a source Formula.

## Distribution model

Public releases use ad-hoc code signing and are not notarized by Apple. This keeps the release process free of Apple Developer Program credentials, but macOS may block the first launch. Users must attempt to open Little Swan, then approve it in **System Settings > Privacy & Security > Open Anyway**.

The release page, Homebrew Cask, and main README must keep this limitation visible. Do not describe an ad-hoc signed archive as notarized or as coming from an identified Apple developer.

## Local packaging

Create a native-architecture ad-hoc signed archive:

```sh
make archive
```

Create the universal archive used for a public release:

```sh
make release ARCHS="arm64 x86_64"
```

The output is `dist/Little-Swan-<version>.zip`. `VERSION` is the source of the release version; `CFBundleShortVersionString` is set while assembling the app.

Verify the ad-hoc signature and bundle version with:

```sh
make verify-app
```

Gatekeeper assessment is expected to reject this build because ad-hoc signing does not establish a trusted developer identity.

## Automated GitHub release

No signing certificate, keychain password, or App Store Connect secret is required. Update `VERSION` and `CHANGELOG.md`, merge the release change, and push a matching tag such as `v0.1.0`.

The release workflow tests the app, creates an ad-hoc signed universal archive, renders a checksum-pinned Cask, and publishes both files to GitHub Releases. Its release notes warn that the build is not notarized.

## Homebrew Cask

`Packaging/Homebrew/little-swan.rb.template` is rendered with the release archive's SHA-256:

```sh
Scripts/render-homebrew-cask.sh 0.1.0 dist/Little-Swan-0.1.0.zip
```

The result is `dist/little-swan.rb`. Publish that file under `Casks/little-swan.rb` in a dedicated public repository named `boundless-forest/homebrew-tap`. Users can then install it with:

```sh
brew install --cask boundless-forest/tap/little-swan
```

The Cask displays the Gatekeeper approval instructions after installation. It must not remove the quarantine attribute automatically; users should make the security decision themselves through macOS System Settings.

Before publishing the Cask, run `brew style`, install it, follow the first-launch approval flow, and uninstall it on both Apple Silicon and Intel macOS 14 or later. The ad-hoc signed build is not eligible for the official `homebrew/cask` repository because it does not pass Gatekeeper without manual intervention.

## Optional notarized release

The `make notarize` target remains available if a future maintainer provides a Developer ID Application identity and a `notarytool` keychain profile:

```sh
make notarize \
  ARCHS="arm64 x86_64" \
  SIGNING_IDENTITY="Developer ID Application: Example (TEAMID)" \
  NOTARY_PROFILE="little-swan-notary"
```

## Release checklist

1. Confirm `swift run LittleSwanSmokeTests` and `swift build -c release` pass.
2. Confirm the copyright notice, asset provenance, privacy text, and security contact remain accurate.
3. Confirm the tag exactly matches `VERSION`.
4. Confirm `make verify-app` accepts the ad-hoc signature and expected bundle version.
5. Confirm the GitHub Release clearly states that the build is not notarized.
6. Test a clean install from the GitHub release ZIP and complete the first-launch approval flow.
7. Render, style, install, launch, and uninstall the Homebrew Cask.
