# Contributing to WinFinder

Thank you for considering a contribution! This document explains how to set up
the project and what a good pull request looks like.

## Development setup

- **macOS 13.0 or newer** and **Xcode 26.6 or newer** (the project uses the
  Xcode 26 project format).
- No Swift Package Manager dependencies — the whole project builds offline.

```sh
git clone https://github.com/hamidreza-tn/WinFinder.git
cd WinFinder
make test
```

`make test` runs, in order:

1. `scripts/validate_project.py` — configuration and contract validation.
2. `scripts/test_project.py` — real unit tests for the shortcut resolver and
   cut state (compiled with `swiftc`), plus source-contract checks.
3. A local Xcode build.

All three must pass before a pull request is reviewed.

## Manual test checklist

Some behaviors cannot be automated offline. If your change touches the event
tap, launch flow, or permissions, walk through this list once:

- [ ] Manual launch opens the Settings window; launching from a login item
      (or after a logout/login) does not show a window.
- [ ] Holding <kbd>Enter</kbd> in Finder opens once and does not start a
      rename; holding <kbd>Backspace</kbd> while renaming keeps erasing
      characters.
- [ ] <kbd>⌘X</kbd> → navigate → <kbd>⌘V</kbd> moves the files; copying
      something else in between (right-click Copy) cancels the move.
- [ ] Toggling Accessibility off in System Settings while running stops the
      interception; re-enabling it (plus activating the app) restores it.
- [ ] F5 asks for Automation permission once; after denying it, the banner
      appears and the deep-link button opens the right pane.
- [ ] The menu-bar pause toggle stops and restores interception; quitting
      releases everything cleanly (no second-instance warning on relaunch).

## Guidelines

- **Keep the shortcut logic pure.** Key-mapping decisions live in
  `WinFinder/ShortcutLogic.swift` as side-effect-free code, and every mapping
  needs a matching assertion in `scripts/logic_tests/main.swift`.
- **Keep UI strings localized.** All user-facing text goes through
  `L10n.tr` in `WinFinder/SettingsViews.swift`, with an entry for every
  supported language (English, Spanish, French, Simplified Chinese, Hindi,
  Persian). English is the fallback language: when you add a key, add it to
  every table.
- **Respect the resource contract.** No polling loops, no repeated timers, no
  network access. The event tap must stay event-driven with bounded recovery
  (`scripts/validate_project.py` enforces this).
- **No personal information.** Do not commit names, email addresses, signing
  credentials, or machine-specific paths.

## Pull requests

1. Create a feature branch from `main`.
2. Make your change and add or update tests.
3. Run `make test` and make sure it passes.
4. Open a pull request with a clear description of what changed and why.

## Reporting bugs

Open an issue and include: macOS version, Mac model (laptop/desktop), the
keyboard layout if relevant, and the console output filtered by
`process == "WinFinder"`.
