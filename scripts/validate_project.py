#!/usr/bin/env python3
"""Offline validation for the checked-in WinFinder project configuration."""

from __future__ import annotations

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "WinFinder.xcodeproj" / "project.pbxproj"
APP = ROOT / "WinFinder"
APP_ICON = APP / "Assets.xcassets" / "AppIcon.appiconset" / "Contents.json"
INFO_PLIST = ROOT / "Config" / "WinFinder-Info.plist"
MAIN_SOURCE = APP / "WinFinderApp.swift"
LOGIC_SOURCE = APP / "ShortcutLogic.swift"
MENU_SOURCE = APP / "MenuBarViews.swift"
SETTINGS_SOURCE = APP / "SettingsViews.swift"
MAKEFILE = ROOT / "Makefile"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"validation failed: {message}")


def read(path: Path) -> str:
    require(path.is_file(), f"missing file: {path}")
    return path.read_text(encoding="utf-8")


project = read(PROJECT)
main_source = read(MAIN_SOURCE)
logic_source = read(LOGIC_SOURCE)
menu_source = read(MENU_SOURCE)
settings_source = read(SETTINGS_SOURCE)
info_plist = read(INFO_PLIST)
makefile = read(MAKEFILE)

# --- Build configuration -----------------------------------------------------
require(project.count("MACOSX_DEPLOYMENT_TARGET = 13.0;") == 2, "deployment target must be 13.0 in Debug and Release")
require(project.count("MARKETING_VERSION = 2.4;") == 2, "marketing version must be 2.4 in Debug and Release")
require(project.count("CURRENT_PROJECT_VERSION = 6;") == 2, "build number must be 6 in Debug and Release")
require(project.count("GENERATE_INFOPLIST_FILE = NO;") == 2, "explicit Info.plist must be used")
require(project.count("INFOPLIST_FILE = Config/WinFinder-Info.plist;") == 2, "custom Info.plist is missing")
require(project.count("PRODUCT_BUNDLE_IDENTIFIER = com.winfinderpro.app;") == 2, "bundle identifier must be the neutral public one")
for key in ("CFBundleShortVersionString", "CFBundleVersion", "LSUIElement", "NSAppleEventsUsageDescription"):
    require(key in info_plist, f"Info.plist is missing {key}")
require("ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;" in project, "missing ASSETCATALOG_COMPILER_APPICON_NAME")

# --- Public-repository hygiene ----------------------------------------------
require((ROOT / "LICENSE").is_file(), "LICENSE file is missing")
require("MIT License" in read(ROOT / "LICENSE"), "LICENSE must be the MIT license")
require((ROOT / "CONTRIBUTING.md").is_file(), "CONTRIBUTING.md is missing")
require((ROOT / ".github" / "workflows" / "build.yml").is_file(), "CI workflow is missing")
require((ROOT / ".github" / "workflows" / "release.yml").is_file(), "release workflow is missing")
for workflow in ("build.yml", "release.yml"):
    require("macos-26" in read(ROOT / ".github" / "workflows" / workflow), f"{workflow} must pin the macos-26 runner (Xcode 26)")
# The marker is assembled at runtime so this scanned file does not itself
# contain the literal it is looking for.
personal_marker = "ha" + "mid"
old_bundle_marker = "com." + personal_marker
# Code and configuration must never contain the personal marker at all.
code_files = [PROJECT, MAIN_SOURCE, LOGIC_SOURCE, MENU_SOURCE, SETTINGS_SOURCE, INFO_PLIST, MAKEFILE,
              ROOT / "scripts" / "validate_project.py", ROOT / "scripts" / "test_project.py",
              ROOT / "scripts" / "logic_tests" / "main.swift",
              ROOT / ".github" / "workflows" / "build.yml", ROOT / ".github" / "workflows" / "release.yml"]
for text_file in code_files:
    require(personal_marker not in read(text_file).lower(), f"personal information found in {text_file.name}")
# Documentation may legitimately reference the public repository owner
# (badges, clone URLs); only the old personal bundle identifier is forbidden.
for text_file in [ROOT / "README.md", ROOT / "CONTRIBUTING.md", ROOT / "LICENSE"]:
    require(old_bundle_marker not in read(text_file).lower(), f"old personal bundle identifier found in {text_file.name}")

# --- Ad-hoc code signing -----------------------------------------------------
require("CODE_SIGN_IDENTITY=-" in makefile, "builds must be ad-hoc signed (CODE_SIGN_IDENTITY=-)")
require("CODE_SIGNING_ALLOWED=NO" not in makefile, "unsigned builds are no longer allowed")

# --- Activation policy and lifecycle ----------------------------------------
require("applicationWillFinishLaunching" in main_source, "early activation-policy hook is missing")
require("NSApp.setActivationPolicy(.accessory)" in main_source, "accessory activation policy is missing")
require("NSApp.setActivationPolicy(.regular)" not in main_source + menu_source + settings_source, "opening settings does not create a Dock icon")
require("return .terminateCancel" not in main_source, "termination must not block shutdown or logout")
require("NotificationCenter.default" in main_source, "application lifecycle notifications use the wrong notification center")

# --- Event tap health --------------------------------------------------------
require("keyboardEventAutorepeat" in main_source, "key repeat protection is missing")
require("maxTapRetryAttempts" in main_source, "event-tap recovery has no bounded retry policy")
require("tapEnable(tap: tap, enable: true)" in main_source, "disabled taps must be re-enabled in place")
require("Thread(name:" in main_source or "thread.name" in main_source, "the event tap must run on its own thread")
require("CFRunLoopStop" in main_source, "the tap run loop must be stopped on teardown")
require("CFRunLoopAddSource(CFRunLoopGetMain()" not in main_source, "the event tap must not run on the main run loop")
require("CGEvent.tapCreate" in main_source, "event tap creation is missing")

# --- Launch context ----------------------------------------------------------
require("kAEOpenApplication" in main_source, "open-application Apple Event observer is missing")
require("isLaunchedAtLogin" in main_source, "login-launch detection is missing")
require("closeAutoOpenedSettingsWindow" in main_source, "login launches must close the auto-opened settings window")
require("showSettingsWindow" in main_source, "user launches must show the settings window explicitly")
require("flock(" in main_source, "single-instance guard must use a kernel flock (no TOCTOU)")
require("allowInPlaceReEnable" in main_source, "in-place tap re-enables must be bounded")
require("activeIssues" in main_source, "the UI banner must show every distinct unresolved issue")
require("isRunningFromPreferredLocation" in main_source, "login-item registration must be gated to /Applications")
require("setPaused" in main_source, "menu-bar pause control is missing")

# --- Login items -------------------------------------------------------------
require("SMAppService.mainApp.register()" in main_source, "login-item registration is missing")
require("SMAppService.mainApp.unregister()" in settings_source, "login-item rollback path is missing")
require("catch" in settings_source and "previousValue" in settings_source, "login-item error rollback is missing")
require("LaunchAtLoginState.isRegistered, forKey" not in main_source, "user intent must not be overwritten with service state")

# --- Shortcut logic ----------------------------------------------------------
require("static let watchedKeys: Set<Int64> = [7, 8, 9" in logic_source, "watched keys contract changed")
require("hasExactModifiers(flags, [])" in logic_source, "exact modifier filtering is missing")
require("keyboardEventAutorepeat" in main_source, "key repeat protection is missing")
require("case 124:" in logic_source, "Alt+Right (forward) mapping is missing")
require("ctrlLayerKeys" in logic_source, "Windows Ctrl layer is missing")
require("backspaceUpFolder" in logic_source and "backspaceUpFolder" in settings_source, "Delete-to-parent-folder toggle is missing")
require("NSPasteboard.general.changeCount" in logic_source, "cut state must be validated against the pasteboard")
require("osascript" in logic_source, "Finder refresh must run through osascript off the main thread")
require("FileHandle.nullDevice" in logic_source, "osascript stdout must go to the null device")
require("environmentObject(appDelegate)" in main_source, "status views observe the real AppDelegate")
require("L10n.tr" in menu_source and "L10n.tr" in settings_source, "UI strings must go through the localization helper")
require("appLanguage" in settings_source, "in-app language switcher is missing")
require("supportedLanguages" in settings_source, "language list is missing")
require("diag.copyreport" in settings_source, "diagnostics copy-report control is missing")
require("delete.inactiveHint" in settings_source, "the overridden trash toggle must say so")

# --- Localization completeness ----------------------------------------------
# Every language table must define exactly the same key set as English, and
# every key referenced from the UI must exist in the tables. A missing entry
# would silently fall back to English (or the raw key) at runtime.
table_keys = {}
for table_name in ("english", "spanish", "french", "chinese", "hindi", "persian"):
    match = re.search(
        r'private static let ' + table_name + r': \[String: String\] = \[(.*?)\n        \]',
        settings_source,
        re.DOTALL,
    )
    require(match is not None, f"localization table '{table_name}' could not be parsed")
    table_keys[table_name] = set(re.findall(r'"([\w.]+)":', match.group(1)))
require(all(table_keys.values()), "localization tables must not be empty")
english_keys = table_keys["english"]
for table_name, keys in table_keys.items():
    require(keys == english_keys, f"localization table '{table_name}' key set differs from the English table "
                                  f"(only in English: {sorted(english_keys - keys)}; missing: {sorted(keys - english_keys)})")

used_keys = set(re.findall(r'L10n\.tr\([^,]+,\s*"([\w.]+)"\)', main_source + menu_source + settings_source))
require(used_keys, "no localization keys are referenced from the UI")
missing_keys = used_keys - english_keys
require(not missing_keys, f"UI keys missing from the localization tables: {sorted(missing_keys)}")
unused_table_keys = english_keys - used_keys
require(not unused_table_keys, f"localization keys no longer used by the UI: {sorted(unused_table_keys)}")
for code, table in (("en", "english"), ("es", "spanish"), ("fr", "french"), ("zh-Hans", "chinese"), ("hi", "hindi"), ("fa", "persian")):
    require(f'private static let {table}: [String: String] = [' in settings_source, f"localization table '{table}' is missing")
    require(f'"{code}": {table},' in settings_source, f"localization table '{table}' is not registered for '{code}'")
require('tables["en"]?[key]' in settings_source, "English must be the fallback localization language")
require("appLanguage = \"en\"" in menu_source and "appLanguage = \"en\"" in settings_source, "English must be the default interface language")
require("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" in settings_source, "Accessibility deep link is missing")
require("x-apple.systempreferences:com.apple.preference.security?Privacy_Automation" in settings_source, "Automation deep link is missing")

# --- App icon ----------------------------------------------------------------
icon = json.loads(read(APP_ICON))
require(icon.get("info", {}).get("version") == 1, "invalid AppIcon asset metadata")
icon_files = [image.get("filename") for image in icon.get("images", [])]
require(all(icon_files), "AppIcon has incomplete image metadata")
require(all((APP_ICON.parent / filename).is_file() for filename in icon_files), "AppIcon references a missing image")

print("WinFinder project validation passed")
