# Repository Guidelines

## Structure
- `Sources/BrowserSwitcherCore/`: browser models, switch coordination, and URL routing rules engine.
- `Sources/BrowserSwitcher/`: AppKit menu bar app, rules window, and macOS adapter.
- `Tests/BrowserSwitcherCoreTests/`: deterministic tests with fake system access.
- `scripts/`: local build and packaging scripts.
- `Assets/`: original generated icon artwork and its generation prompts; build scripts produce platform sizes without changing the source images.
- `dist/`: generated application bundles, excluded from version control.

## Rules
- Use Swift and AppKit without third-party dependencies. Support macOS 12 and later.
- Limit changes to the approved menu bar browser switcher and URL router scope.
- Never change real default browser settings during automated tests.
- Ask the user before real system configuration changes, deletion, global installs, or publishing.
- Run `swift run BrowserSwitcherCoreTests` and `bash scripts/build-app.sh` after implementation changes.
- Tests use a standalone assertion runner because Command Line Tools does not include XCTest or Swift Testing. Failed assertions must produce a nonzero exit code.
- Keep README.md for usage and ROADMAP.md for verified progress and remaining work.
- Never mark a runtime behavior complete without verification evidence.
