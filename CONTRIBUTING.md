# Contributing

Thanks for helping make Cat Protector better. It is a small app on purpose, so the bar for a change is: does this make it simpler, safer, or more useful for someone with a cat on their keyboard?

## Getting set up

```bash
git clone https://github.com/YOUR-USERNAME/cat-protector.git
cd cat-protector
make test   # run the unit tests
make run    # build the .app and launch it
```

You need Xcode or the Command Line Tools on macOS 13 or later. There are no third-party dependencies.

After every rebuild macOS forgets the app's Accessibility permission, because the app is signed ad hoc. Toggle it off and on in System Settings → Privacy & Security → Accessibility.

## Guidelines

- **Keep the lock logic pure.** Anything that decides whether an event passes or is dropped belongs in `LockEngine.swift` and should come with a test in `Tests/CatProtectorTests`.
- **Never add tracking, networking, or telemetry.** Cat Protector reads input for the whole system; the only way that is acceptable is if it demonstrably does nothing with it. `TrustTests.swift` fails the build if networking, file writing, or process spawning appears in `Sources/`.
- **Keep the toggle path instant.** Nothing that runs when the lock flips should allocate, load from disk, or talk to another process. Measure with the timing log in the README if in doubt.
- **Prefer no new settings.** If a behaviour is right for almost everyone, make it the default instead of adding a checkbox.
- **Test with a real cat if you can.** Failing that, a forearm on the keyboard works surprisingly well.

## Reporting bugs

Use the bug report template. Include your macOS version, how you installed the app, and what happened. If the shortcut did not unlock the Mac, please say which keyboard and layout you use.

## Pull requests

1. Fork and create a branch.
2. Make your change and add or update tests.
3. Run `make test` and `make app` and make sure both succeed.
4. Open a pull request describing what changed and why.

By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md).
