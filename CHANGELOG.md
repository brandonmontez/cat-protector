# Changelog

All notable changes to Cat Protector are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-09-04

Initial release.

- Lock and unlock the keyboard, trackpad, mouse, scroll, gestures, and media keys with one global shortcut (default ⌃⌥⌘L).
- Menu bar app with no Dock icon. The item shows the unlock shortcut while locked.
- On-screen banner and sound on lock and unlock, both optional.
- On-demand reminder for full-screen apps: a small pill appears for a moment when a blocked key press or click happens.
- Configurable shortcut with a built-in recorder. Shortcuts must include ⌃, ⌥, or ⌘.
- Start at Login.
- Input handling on a dedicated thread, with instant feedback: audio warmed up at launch, banner pre-rendered.
- Debug timing logs for latency investigation.
- Unit tests for the lock engine, shortcut handling, and a trust test that forbids networking, file writing, and process spawning in the app sources.
