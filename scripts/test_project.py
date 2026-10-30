#!/usr/bin/env python3
"""Offline regression checks plus real unit tests for the shortcut logic.

The contract checks grep the source for behaviour contracts that are easy to
break silently. The logic tests compile ShortcutLogic.swift together with a
small test main and execute the resolver and cut-state assertions, so the
actual key mappings are verified, not just their presence in the source.
"""

import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MAIN_SOURCE = ROOT / "WinFinder" / "WinFinderApp.swift"
LOGIC_SOURCE = ROOT / "WinFinder" / "ShortcutLogic.swift"
TEST_MAIN = ROOT / "scripts" / "logic_tests" / "main.swift"
TEST_BINARY = ROOT / ".build" / "WinFinderLogicTests"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"test failed: {message}")


main_source = MAIN_SOURCE.read_text(encoding="utf-8")
logic_source = LOGIC_SOURCE.read_text(encoding="utf-8")

# --- Source contracts --------------------------------------------------------
require("NotificationCenter.default" in main_source, "Accessibility lifecycle uses the app notification center")
require("keyboardEventAutorepeat" in main_source, "single-shot shortcuts protect against key repeat")
require("hasExactModifiers(flags, .maskCommand)" in logic_source, "shortcuts use exact modifier matching")
require("static let watchedKeys: Set<Int64> = [7, 8, 9" in logic_source, "Cmd+C invalidates stale cut state")
require("return .terminateCancel" not in main_source, "termination cannot block logout or shutdown")
require("NSApp.setActivationPolicy(.accessory)" in main_source, "the app remains a menu-bar agent")
require("NSApp.setActivationPolicy(.regular)" not in main_source, "opening settings does not create a Dock icon")
require(".environmentObject(appDelegate)" in main_source, "status views observe the real AppDelegate")
require("heartbeatTimer" not in main_source + logic_source, "idle mode has no repeating battery wakeup")
require("maxTapRetryAttempts" in main_source, "event-tap recovery remains bounded and event-driven")
require("consume(currentChangeCount:" in logic_source, "cut state is validated against the pasteboard")
require("tapEnable(tap: tap, enable: true)" in main_source, "event tap recovers in place without losing keystrokes")

# --- Real logic tests --------------------------------------------------------
TEST_BINARY.parent.mkdir(parents=True, exist_ok=True)
compile_result = subprocess.run(
    [
        "swiftc",
        str(LOGIC_SOURCE),
        str(TEST_MAIN),
        "-o",
        str(TEST_BINARY),
    ],
    capture_output=True,
    text=True,
)
if compile_result.returncode != 0:
    print(compile_result.stdout)
    print(compile_result.stderr, file=sys.stderr)
    raise SystemExit("test failed: logic tests did not compile")

run_result = subprocess.run([str(TEST_BINARY)], capture_output=True, text=True)
print(run_result.stdout, end="")
if run_result.returncode != 0:
    print(run_result.stderr, file=sys.stderr)
    raise SystemExit("test failed: logic tests reported failures")

print("WinFinder offline regression checks passed")
