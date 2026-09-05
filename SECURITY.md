# Security

## What Cat Protector can see

Cat Protector installs a system-wide input event tap. While it is running it can observe every key press, click, and scroll on the machine. That is the only way to block them before other apps receive them, and it is exactly why the app is built to be trivially auditable:

- **No networking.** There is no network code of any kind. A test in `Tests/CatProtectorTests/TrustTests.swift` fails the build if networking, process spawning, or file writing is ever added to the app's sources.
- **No logging of input.** Key codes are compared against the shortcut and then dropped or passed through. Nothing is stored.
- **No files.** The only persisted data is the shortcut and two on/off preferences, in the app's own `UserDefaults`.
- **Small.** The whole app is a handful of Swift files with no dependencies. Read them; it takes fifteen minutes.

## Reporting a vulnerability

If you believe you have found a security problem, please do not open a public issue. Use GitHub's private vulnerability reporting on this repository's **Security** tab. You will get a response as soon as a maintainer sees it, and a fix will be released before details are published.

## Supported versions

Only the latest release is supported. Cat Protector has no update mechanism, so please check the Releases page occasionally.
