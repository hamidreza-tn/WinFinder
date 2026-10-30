// Offline unit tests for WinFinder's pure shortcut logic.
// Compiled together with WinFinder/ShortcutLogic.swift by scripts/test_project.py.

import Foundation
import CoreGraphics

var failures = 0

func expect(_ condition: Bool, _ message: String) {
    if condition {
        print("ok: \(message)")
    } else {
        failures += 1
        print("FAIL: \(message)")
    }
}

func resolve(_ keyCode: Int64, _ flags: CGEventFlags, _ settings: ShortcutSettings = ShortcutSettings()) -> ShortcutAction? {
    ShortcutResolver.action(for: keyCode, flags: flags, settings: settings)
}

// MARK: - Enter / properties

expect(resolve(36, []) == .synthesizeKey(keyCode: 125, flags: .maskCommand), "Enter opens via Cmd+Down")
expect(resolve(36, .maskCommand) == nil, "Cmd+Enter is untouched")
expect(resolve(36, .maskShift) == nil, "Shift+Enter is untouched")
expect(resolve(36, .maskAlternate) == .synthesizeKey(keyCode: 34, flags: .maskCommand), "Alt+Enter opens Get Info (Cmd+I)")
expect(resolve(36, [.maskAlternate, .maskShift]) == nil, "Alt+Shift+Enter is untouched")

// MARK: - Delete family

expect(resolve(51, []) == .synthesizeKey(keyCode: 51, flags: .maskCommand), "Delete moves to Trash via Cmd+Delete")
expect(resolve(51, .maskShift) == .synthesizeKey(keyCode: 51, flags: [.maskAlternate, .maskCommand]), "Shift+Delete deletes immediately")
let parentFolderOn = ShortcutSettings(backspaceUpFolder: true)
expect(resolve(51, [], parentFolderOn) == .synthesizeKey(keyCode: 126, flags: .maskCommand), "Delete goes to parent folder when that toggle wins")
expect(resolve(51, .maskShift, parentFolderOn) == .synthesizeKey(keyCode: 51, flags: [.maskAlternate, .maskCommand]), "Shift+Delete still deletes immediately with parent toggle on")

// MARK: - Rename

expect(resolve(15, .maskCommand) == .synthesizeKey(keyCode: 36, flags: []), "Cmd+R starts rename")
expect(resolve(120, []) == .synthesizeKey(keyCode: 36, flags: []), "F2 starts rename")

// MARK: - Cut and paste

expect(resolve(7, .maskCommand) == .beginCut, "Cmd+X begins a cut")
expect(resolve(9, .maskCommand) == .pasteAfterCut, "Cmd+V becomes move-after-cut")
expect(resolve(7, [.maskCommand, .maskAlternate]) == nil, "Cmd+Alt+X is untouched")
expect(resolve(7, .maskControl) == .beginCut, "Ctrl+X cuts like Cmd+X")
expect(resolve(9, .maskControl) == .pasteAfterCut, "Ctrl+V pastes like Cmd+V")
let cutLayerOff = ShortcutSettings(cutAndPaste: false)
expect(resolve(7, .maskControl, cutLayerOff) == nil, "Ctrl+X untouched when cut support is off")
expect(resolve(9, .maskControl, cutLayerOff) == nil, "Ctrl+V untouched when cut support is off")

// MARK: - Alt navigation (all four directions)

expect(resolve(126, .maskAlternate) == .synthesizeKey(keyCode: 126, flags: .maskCommand), "Alt+Up goes to parent")
expect(resolve(125, .maskAlternate) == .synthesizeKey(keyCode: 125, flags: .maskCommand), "Alt+Down opens")
expect(resolve(123, .maskAlternate) == .synthesizeKey(keyCode: 33, flags: .maskCommand), "Alt+Left goes back")
expect(resolve(124, .maskAlternate) == .synthesizeKey(keyCode: 30, flags: .maskCommand), "Alt+Right goes forward")
expect(resolve(124, [.maskAlternate, .maskShift]) == nil, "Alt+Shift+Right is untouched")

// MARK: - F5 refresh and ignored non-modifier flags

expect(resolve(96, []) == .refreshFinder, "F5 refreshes Finder")
expect(resolve(96, .maskSecondaryFn) == .refreshFinder, "fn+F5 still refreshes (fn is ignored)")
expect(resolve(96, [.maskSecondaryFn, .maskAlphaShift]) == .refreshFinder, "caps lock does not break shortcuts")
expect(resolve(96, .maskControl) == nil, "Ctrl+F5 is untouched")

// MARK: - Ctrl layer

expect(resolve(0, .maskControl) == .synthesizeKey(keyCode: 0, flags: .maskCommand), "Ctrl+A maps to Cmd+A")
expect(resolve(3, .maskControl) == .synthesizeKey(keyCode: 3, flags: .maskCommand), "Ctrl+F maps to Cmd+F")
expect(resolve(13, .maskControl) == .synthesizeKey(keyCode: 13, flags: .maskCommand), "Ctrl+W maps to Cmd+W")
expect(resolve(17, .maskControl) == .synthesizeKey(keyCode: 17, flags: .maskCommand), "Ctrl+T maps to Cmd+T")
expect(resolve(31, .maskControl) == .synthesizeKey(keyCode: 31, flags: .maskCommand), "Ctrl+O maps to Cmd+O")
expect(resolve(45, .maskControl) == .synthesizeKey(keyCode: 45, flags: .maskCommand), "Ctrl+N maps to Cmd+N")
expect(resolve(45, [.maskControl, .maskShift]) == .synthesizeKey(keyCode: 45, flags: [.maskCommand, .maskShift]), "Ctrl+Shift+N maps to Cmd+Shift+N")
expect(resolve(8, .maskControl) == .synthesizeKey(keyCode: 8, flags: .maskCommand), "Ctrl+C maps to Cmd+C")
expect(resolve(6, .maskControl) == .synthesizeKey(keyCode: 6, flags: .maskCommand), "Ctrl+Z maps to Cmd+Z")
expect(resolve(1, .maskControl) == .synthesizeKey(keyCode: 1, flags: .maskCommand), "Ctrl+S maps to Cmd+S")
expect(resolve(35, .maskControl) == .synthesizeKey(keyCode: 35, flags: .maskCommand), "Ctrl+P maps to Cmd+P")
expect(resolve(37, .maskControl) == .synthesizeKey(keyCode: 5, flags: [.maskCommand, .maskShift]), "Ctrl+L opens Go to Folder (Cmd+Shift+G)")
expect(resolve(37, .maskCommand) == nil, "plain Cmd+L is untouched")
expect(resolve(2, .maskControl) == nil, "Ctrl+D is untouched (outside the layer)")
expect(resolve(0, .maskCommand) == nil, "plain Cmd+A is untouched")
let ctrlLayerOff = ShortcutSettings(ctrlShortcuts: false)
expect(resolve(0, .maskControl, ctrlLayerOff) == nil, "Ctrl layer can be disabled")
expect(resolve(8, .maskControl, ctrlLayerOff) == nil, "Ctrl+C can be disabled")
expect(resolve(37, .maskControl, ctrlLayerOff) == nil, "Ctrl+L can be disabled")

// MARK: - Disabled toggles

let allOff = ShortcutSettings(
    enterToOpen: false, deleteToTrash: false, shiftDeletePermanent: false, cmdRRename: false,
    cutAndPaste: false, altEnterProperties: false, altNavFolders: false, f5Refresh: false,
    backspaceUpFolder: false, ctrlShortcuts: false
)
expect(resolve(36, [], allOff) == nil, "Enter untouched when disabled")
expect(resolve(51, [], allOff) == nil, "Delete untouched when disabled")
expect(resolve(7, .maskCommand, allOff) == nil, "Cmd+X untouched when cut disabled")
expect(resolve(9, .maskCommand, allOff) == nil, "Cmd+V untouched when cut disabled")
expect(resolve(96, [], allOff) == nil, "F5 untouched when disabled")

// MARK: - Cut state

let cut = CutState()
expect(!cut.consume(currentChangeCount: 1), "consume without a cut returns false")
cut.mark()
cut.captureBaseline(10)
expect(!cut.consume(currentChangeCount: 11), "a later copy (changed pasteboard) invalidates the cut")
expect(!cut.consume(currentChangeCount: 10), "the invalidated cut cannot be consumed twice")

let cut2 = CutState()
cut2.mark()
cut2.captureBaseline(10)
expect(cut2.consume(currentChangeCount: 10), "cut is valid when the pasteboard is unchanged")

let cut3 = CutState()
cut3.mark()
expect(cut3.consume(currentChangeCount: 5), "cut stays valid before the baseline is captured")

let cut4 = CutState()
cut4.mark()
cut4.clear()
expect(!cut4.consume(currentChangeCount: 5), "a cleared cut cannot be consumed")

// MARK: - Watched keys

for keyCode in [Int64(0), 1, 3, 6, 7, 8, 9, 13, 15, 17, 31, 35, 36, 37, 45, 51, 96, 120, 123, 124, 125, 126] {
    expect(ShortcutResolver.watchedKeys.contains(keyCode), "key \(keyCode) is watched")
}

// MARK: - Finder refresh outcome classification

expect(FinderAutomation.classify(terminationStatus: 0, stderr: "") == .success, "a clean exit is a success")
expect(FinderAutomation.classify(terminationStatus: 1, stderr: "execution error: Finder got an error (-1743)") == .denied, "the Apple Events denial is detected")
expect(FinderAutomation.classify(terminationStatus: 1, stderr: "Can't get front window. (-1728)") == .noWindow, "no open window is benign")
expect(FinderAutomation.classify(terminationStatus: 1, stderr: "some other error") == .failed("some other error"), "other errors are reported as failures")
expect(FinderAutomation.classify(terminationStatus: 143, stderr: "") == .failed(""), "a watchdog kill is a failure")

if failures == 0 {
    print("WinFinder logic tests passed")
} else {
    print("\(failures) logic test(s) failed")
    exit(1)
}
