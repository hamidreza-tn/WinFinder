<div align="center">

# ⌨️ WinFinder Pro

**Windows-style keyboard shortcuts for macOS Finder.**

Stop re-training your muscle memory — use the shortcuts you already know.

[![Build & Test](https://github.com/hamidreza-tn/WinFinder/actions/workflows/build.yml/badge.svg)](https://github.com/hamidreza-tn/WinFinder/actions/workflows/build.yml)
[![Release](https://github.com/hamidreza-tn/WinFinder/actions/workflows/release.yml/badge.svg)](https://github.com/hamidreza-tn/WinFinder/actions/workflows/release.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-13.0%2B-black)](#installation)
[![Swift](https://img.shields.io/badge/Swift-5-orange)](#building-from-source)
[![Languages](https://img.shields.io/badge/languages-6-green)](#languages)

</div>

---

WinFinder is a lightweight, open-source menu-bar utility that brings the
Windows keyboard experience to macOS Finder. It is a single, small app with no
dependencies, no network access, and no background polling — built with Swift
and SwiftUI.

## Highlights

| Windows habit | With WinFinder |
| --- | --- |
| <kbd>Enter</kbd> opens the selected item | ✔ Opens files and folders (Finder's default is *rename*) |
| <kbd>Del</kbd> moves to the Recycle Bin | ✔ Moves to Trash |
| <kbd>Shift</kbd> + <kbd>Del</kbd> deletes permanently | ✔ Deletes immediately, skipping the Trash |
| <kbd>F2</kbd> renames | ✔ F2 or <kbd>⌘R</kbd> starts a rename |
| <kbd>Ctrl</kbd>+<kbd>X</kbd> / <kbd>Ctrl</kbd>+<kbd>V</kbd> cut & paste | ✔ <kbd>⌘X</kbd> cuts and <kbd>⌘V</kbd> moves, like Windows |
| <kbd>Alt</kbd>+<kbd>Enter</kbd> shows properties | ✔ Opens Get Info |
| <kbd>Backspace</kbd> / <kbd>Alt</kbd>+<kbd>↑↓←→</kbd> navigate | ✔ Up / open / back / forward (all four directions) |
| <kbd>F5</kbd> refreshes | ✔ Refreshes the active Finder window |

Plus an optional **Windows Ctrl layer** that maps your Windows <kbd>Ctrl</kbd>
habits onto their <kbd>⌘</kbd> equivalents — <kbd>Ctrl</kbd>+<kbd>C</kbd>,
<kbd>X</kbd>, <kbd>V</kbd>, <kbd>Z</kbd>, <kbd>S</kbd>, <kbd>P</kbd>,
<kbd>A</kbd>, <kbd>F</kbd>, <kbd>N</kbd>, <kbd>W</kbd>, <kbd>T</kbd>,
<kbd>O</kbd>, plus <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>N</kbd> (new folder)
and <kbd>Ctrl</kbd>+<kbd>L</kbd> (Go to Folder, the Explorer address bar) —
inside Finder only, never while you are typing in a text field.

## Known differences from Windows

A few behaviors cannot match Windows exactly on macOS; they are deliberate:

- **Shift+Delete asks for confirmation** — it triggers macOS's own
  "Delete Immediately" dialog, which always confirms.
- **Cut has no visual highlight** — Finder offers no public API to gray out
  cut items the way Explorer does.
- **Cut with nothing selected** leaves the previous clipboard content in
  place; a later paste then moves that older content (Windows pastes it as a
  copy instead).

## Compatibility

WinFinder coexists with other keyboard tools (Karabiner-Elements sits below
the event system, BetterTouchTool/Keyboard Maestro above it), but installing
more than one tool that remaps the same keys in Finder can still cause double
remapping. If shortcuts behave strangely, pause WinFinder from the menu bar to
isolate the conflict.

## Troubleshooting

- **Shortcuts don't work at all** — check the Accessibility permission
  (Settings → *Open Accessibility settings*, or the Diagnostics section).
- **F5 does nothing** — laptops with media-key defaults need
  <kbd>fn</kbd>+<kbd>F5</kbd>; the first press also asks for the **Automation**
  (Apple Events) permission.
- **Shortcuts stopped after updating the app** — the Accessibility grant can
  reset when the binary's identity changes; re-enable WinFinder under
  *System Settings → Privacy & Security → Accessibility* once.
- **A settings window appears at every login** — this should not happen since
  2.2 (login launches are detected and stay quiet). If it does, please open an
  issue with the console output filtered by `process == "WinFinder"`.

Everything is configurable: every shortcut group can be toggled independently
from the Settings window, and a live cheat-sheet shows exactly which shortcuts
are active.

## Features

- 🔪 **Cut & move** — true Windows-style cut for files (copy + move-on-paste);
  the cut state is invalidated automatically if anything else is copied
- 🧭 **Full navigation set** — parent folder, open, back and forward
- 🗑️ **Delete & Shift+Delete** — to Trash or permanently
- ⌨️ **Windows Ctrl layer** — Ctrl+C/X/V/Z/S/P/A/F/N/W/T/O, Ctrl+L (Go to
  Folder), Ctrl+Shift+N (new folder)
- ⏻ **Launch at login** — registered via `SMAppService`, with an honest toggle
  that reflects the real service state
- 🌐 **6 interface languages** — English, Español, Français, 简体中文, हिन्दी,
  فارسی (with full RTL layout for Persian)
- 🚦 **Menu bar control** — status icon, one-click pause/resume (or pause for
  an hour), a live list of active shortcuts, Settings, About, Quit
- 🗂️ **Tabbed Settings** — Shortcuts / System / Status tabs with a live
  cheat-sheet, diagnostics with a copyable report, settings export & import,
  and a reset-to-defaults control
- 🧪 **Tested** — the shortcut resolver and cut state have real unit tests,
  and configuration contracts are validated on every build
- 🔋 **Battery friendly** — no polling loops, no heartbeat timers; the event
  tap is event-driven with bounded, in-place recovery
- 🛟 **Helpful onboarding** — permission prompts, direct deep links to the
  Accessibility and Automation panes, and human-readable error banners

## Installation

### Download a ready build

Grab the latest `WinFinder.zip` from the
[**Releases**](https://github.com/hamidreza-tn/WinFinder/releases) page,
unzip it, and move `WinFinder.app` into `/Applications`.

> The released builds are ad-hoc signed. On first launch, macOS asks for
> **Accessibility** permission — grant it and the shortcuts start working.

### Build from source

Requirements: **macOS 13.0+** and **Xcode 26.6+**.

```sh
git clone https://github.com/hamidreza-tn/WinFinder.git
cd WinFinder
make install          # validates, builds, and installs to /Applications
open /Applications/WinFinder.app
```

The launch-at-login toggle works from any location, but the automatic
first-run registration only happens when the app lives in `/Applications` — a
hint appears in Settings otherwise.

## Getting started

1. **Launch the app** — it lives in the **menu bar** (a keyboard icon); the
   Settings window opens on a user launch.
2. **Grant Accessibility** when prompted, or use the *Grant Access* button /
   deep link in Settings. The status icon turns into a filled keyboard when
   everything is active.
3. **Press F5 in Finder** — the first press asks for **Automation**
   (Apple Events) permission so WinFinder can refresh Finder windows.
4. Open a Finder window and try <kbd>Enter</kbd>, <kbd>⌘X</kbd> →
   <kbd>⌘V</kbd>, <kbd>F2</kbd>, <kbd>Alt</kbd>+<kbd>↑</kbd>…

Shortcuts are active **only in Finder** and only when a file browser has
focus — typing in any text field, in any app, is never affected. You can pause
everything at any time from the menu bar.

## Privacy

WinFinder collects **nothing**. There is no network access, no analytics, no
crash reporting, and nothing is written to disk except your own preferences.
Keyboard events are inspected locally to decide whether a shortcut applies and
are never stored, logged, or transmitted. The entire codebase is small enough
to read in one sitting — that is the privacy policy.

## How it works

WinFinder installs a single keyboard event tap (`CGEventTap`) and rewrites a
small, explicitly configured set of keystrokes when Finder is the frontmost
application: for example, <kbd>Enter</kbd> is replaced by
<kbd>⌘↓</kbd> (open), and <kbd>⌘X</kbd> becomes a copy followed by a
"move here" (<kbd>⌘⌥V</kbd>) on the next paste. The tap runs on its own
thread, recovers in place if macOS disables it, and shuts down cleanly when
you pause or quit. F5 refreshes Finder through Apple Events via `osascript`.

## Building from source

```sh
make validate   # configuration + contract checks
make test       # unit tests + full build (offline, no dependencies)
make archive    # ad-hoc signed .xcarchive in .build/
```

| Path | Purpose |
| --- | --- |
| `WinFinder/WinFinderApp.swift` | App lifecycle, event tap, permissions, launch detection |
| `WinFinder/ShortcutLogic.swift` | Pure shortcut resolver, cut state, key simulation |
| `WinFinder/MenuBarViews.swift` | Menu bar icon and menu |
| `WinFinder/SettingsViews.swift` | Settings UI and all 6 localization tables |
| `scripts/` | Offline validation + unit-test runner |
| `.github/workflows/` | CI build and release pipelines |

Continuous Integration runs `make test` on every push and pull request on a
macOS 26 runner (Xcode 26), and tagged commits (`v*`) automatically produce a
zipped app in a GitHub Release.

## Languages

English (default), Español, Français, 简体中文, हिन्दी, and فارسی. The
language can be changed at any time from **Settings → System → Interface
language**; missing translations always fall back to English.

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for
the development setup and guidelines — in short: keep the shortcut logic pure
and tested, keep every string localized, and run `make test` before opening a
pull request.

## License

This project is licensed under the [MIT License](LICENSE).
