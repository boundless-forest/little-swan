# Changelog

All notable changes to Little Swan will be documented in this file.

## Unreleased

## 0.1.2 - 2026-07-16

### Changed

- Refined the app icon with production vector artwork based on the approved precision-origami Little Swan design.
- Added a dedicated monochrome menu bar optical master that remains legible across light and dark appearances.
- Replaced screenshot extraction and Pillow with a deterministic Swift/AppKit pipeline that generates PNG and ICNS assets from checked-in SVG masters.

## 0.1.1 - 2026-07-16

### Added

- An About settings tab showing the release version, build provenance, and links to the matching GitHub release and source commit.
- A configurable Generate translation shortcut in Settings, with conflict-safe persistence and a Command-Return default.

## 0.1.0 - 2026-07-16

### Added

- Source-publication guidance plus security, privacy, CI, release, notarization, and Homebrew Cask preparation.
- Restrictive source-available copyright notice that grants no permission to use, modify, or distribute the code.

### Changed

- Writing styles are focused on Spoken English and Formal English, with compatibility migration for previously saved styles.
- Remote provider endpoints require HTTPS; loopback development endpoints may continue using HTTP.
- Public release archives now use ad-hoc signing without Apple notarization and document the required first-launch Gatekeeper approval.

- Initial release preparation.
