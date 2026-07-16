# Contributing to Little Swan

Little Swan is currently source-available with all rights reserved. No license is granted to use, modify, or distribute the code.

External code contributions are not currently accepted because no contribution or redistribution license has been established. Please use issues for bug reports and product feedback, and do not open pull requests containing code changes until this policy is updated.

## Before opening a change

- Use an issue for behavior changes that need product discussion.
- Use the private security-reporting path described in [SECURITY.md](SECURITY.md) for vulnerabilities.

## Local development

Little Swan requires macOS 14 or later and Swift 6.0 or later.

```sh
swift build
swift run LittleSwanSmokeTests
swift run LittleSwan
```

To build a local ad-hoc-signed app bundle:

```sh
make app
open "Little Swan.app"
```

## Maintainer changes

Maintainers should run `swift run LittleSwanSmokeTests` and `swift build -c release`, update tests and documentation for behavior changes, and confirm that no credentials, personal drafts, or generated app bundles are included.
