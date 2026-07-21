# Changelog

All notable changes to Little Swan will be documented in this file.

## Unreleased

## 0.1.4 - 2026-07-21

### Added

- Configurable Control-Tab and Control-Shift-Tab shortcuts cycle forward and backward through all five Drafts.
- A dedicated Draft menu exposes both navigation commands while keeping them scoped to the active main window.

### Changed

- Keyboard Draft switching now preserves Source editor focus and wraps cleanly between Draft 1 and Draft 5.

## 0.1.3 - 2026-07-17

### Added

- Source-first Polish now organizes multi-batch dictation and mixed-language recognition errors even when screen context is disabled or unavailable.
- Optional screen context locks the exact external window used before Little Swan opens and exposes a user-facing setting to disable capture.

### Fixed

- Screen capture, OCR, and permission failures now fall back to Source-only Polish instead of blocking the feature.
- Multi-display capture no longer substitutes another visible window when the locked target closes or becomes unavailable.
- ScreenCaptureKit imports now remain compatible with the Xcode 16.4 SDK used by GitHub Actions release builds.

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
