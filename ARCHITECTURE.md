# Architecture

A short map of how WinFinder works, for contributors. The whole app is a
handful of files; this explains how they connect.

## Data flow of a keystroke

```
macOS keyboard
   │  (system-wide CGEventTap: .cghidEventTap, head insert, keyDown only)
   ▼
AppDelegate.handleKeyEvent            WinFinderApp.swift — runs on a dedicated
   │                                    thread ("WinFinder EventTap"), never the
   │                                    main run loop, so a stalled UI cannot
   │                                    delay system-wide keyboard input.
   ├─ tapDisabled notifications → bounded in-place re-enable → bounded retry
   ├─ synthetic-event marker?  → pass through (events WinFinder posted itself)
   ├─ watchedKeys gate         → unwatched keys pass untouched
   ├─ ⌘C anywhere              → invalidate any pending cut state
   ▼
ShortcutResolver.action(for:flags:settings:)   ShortcutLogic.swift — PURE
   │                                            mapping, fully unit-tested
   │                                            (scripts/logic_tests/main.swift)
   ▼
ShortcutAction
   ├─ .synthesizeKey(key, flags) → KeySimulator.post (marked synthetic event)
   ├─ .beginCut                  → synthesize ⌘C + CutState.mark()
   ├─ .pasteAfterCut             → CutState.consume(changeCount) → ⌘⌥V, else
   │                               fall back to a normal paste
   └─ .refreshFinder             → FinderAutomation (osascript, background queue)
```

Guard order in `handleKeyEvent` matters: autorepeats are decided from a cached
"was the first press intercepted or passed to a text field?" decision, so
holding a key in a text field keeps repeating natively while an intercepted
key stays single-shot.

## Files

| File | Responsibility |
| --- | --- |
| `WinFinder/WinFinderApp.swift` | `@main` scenes, `AppDelegate`: lifecycle, event tap thread, permissions, launch-source detection (Apple Event `oapp`), single-instance flock, pause, issues |
| `WinFinder/ShortcutLogic.swift` | Pure shortcut resolver, `ShortcutSettings`, `CutState`, `KeySimulator`, `TextEditingDetector`, `FinderAutomation`, `TapRunLoopHolder` |
| `WinFinder/MenuBarViews.swift` | Menu bar icon (state-aware) and menu |
| `WinFinder/SettingsViews.swift` | Settings UI, all six `L10n` tables, diagnostics, deep links |

## Key invariants

- **No polling.** Recovery is event-driven (system wake, app activation,
  tap-disabled notifications); in-place re-enables are bounded before the
  bounded retry takes over. `scripts/validate_project.py` enforces this.
- **Cut state is pasteboard-validated.** The cut is a copy + move-on-paste;
  any later copy (different pasteboard change count) invalidates it.
- **Finder-only, text-safe.** Remapping applies only when Finder is
  frontmost and the focused element is not a text field/area.
- **All UI strings go through `L10n`** with English as the fallback language;
  every table must define every key (`validate_project.py` checks the tables
  exist, the test suite checks behavior).
- **No personal information** in any tracked file.

## Design decisions

- **Custom `L10n` dictionaries instead of String Catalogs.** WinFinder offers
  an in-app language switcher with six languages. String Catalogs resolve per
  system locale; overriding the locale per view (`\.environment(\.locale, …)`)
  is unreliable for switching the entire UI at runtime. The dictionary tables
  are validated for completeness (`validate_project.py` requires every table
  to define exactly the English key set, and every UI-referenced key to exist),
  which is the guarantee String Catalogs would otherwise provide.
- **No DerivedData cache in CI.** The build takes ~2–3 minutes and a shared
  cache risks stale-module failures; caching would save less than a minute.
- **Enabling notarized releases (future).** With a paid Apple Developer
  account: create a *Developer ID Application* certificate, add
  `DEVELOPER_ID_IDENTITY`, `NOTARYTOOL_PROFILE` (via `xcrun notarytool
  store-credentials`) values as repository secrets, then extend
  `.github/workflows/release.yml` to sign the built app with the identity,
  submit it with `xcrun notarytool submit`, staple the ticket
  (`xcrun stapler staple`), and zip the stapled bundle. Until then, releases
  are ad-hoc signed and macOS shows a one-time Gatekeeper warning
  (right-click → Open).

## Release flow

`make test` locally → push → CI (Build & Test on `macos-26`) → tag `v*` →
Release workflow builds, zips, and publishes a GitHub Release automatically.
