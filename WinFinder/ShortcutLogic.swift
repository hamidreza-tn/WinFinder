import Foundation
import AppKit
import ApplicationServices

// MARK: - تنظیمات میانبرها (اسنپ‌شات)
/// A point-in-time snapshot of the user's shortcut toggles. Reading every
/// value once per intercepted keystroke keeps the event callback cheap and
/// avoids repeated UserDefaults bridging on the tap thread.
struct ShortcutSettings: Equatable {
    var enterToOpen = true
    var deleteToTrash = true
    var shiftDeletePermanent = true
    var cmdRRename = true
    var cutAndPaste = true
    var altEnterProperties = true
    var altNavFolders = true
    var f5Refresh = true
    var backspaceUpFolder = false
    var ctrlShortcuts = true
}

extension ShortcutSettings {
    /// Reads the live toggles from the given defaults database. The synthesized
    /// memberwise initializer (with the compiled-in defaults) is only meant for
    /// tests; the app must always read the user's toggles via this initializer.
    init(defaults: UserDefaults) {
        self.init(
            enterToOpen: defaults.bool(forKey: "enterToOpen"),
            deleteToTrash: defaults.bool(forKey: "deleteToTrash"),
            shiftDeletePermanent: defaults.bool(forKey: "shiftDeletePermanent"),
            cmdRRename: defaults.bool(forKey: "cmdRRename"),
            cutAndPaste: defaults.bool(forKey: "cutAndPaste"),
            altEnterProperties: defaults.bool(forKey: "altEnterProperties"),
            altNavFolders: defaults.bool(forKey: "altNavFolders"),
            f5Refresh: defaults.bool(forKey: "f5Refresh"),
            backspaceUpFolder: defaults.bool(forKey: "backspaceUpFolder"),
            ctrlShortcuts: defaults.bool(forKey: "ctrlShortcuts")
        )
    }
}

// MARK: - نگاشت کلید به عمل
/// The single remapping decision the event tap makes for a key press.
enum ShortcutAction: Equatable {
    /// Post a synthetic key event with the given virtual key and modifiers.
    case synthesizeKey(keyCode: Int64, flags: CGEventFlags)
    /// Cmd+X: post a synthetic Cmd+C (copy) and mark the cut state.
    case beginCut
    /// Cmd+V while the cut state is valid: post Cmd+Option+V (move here).
    case pasteAfterCut
    /// F5: ask Finder to refresh the front window.
    case refreshFinder
}

enum ShortcutResolver {
    /// Key codes whose keyDown events are observed by the event tap.
    /// Copy (8) is observed only to invalidate a stale cut state.
    static let watchedKeys: Set<Int64> = [7, 8, 9, 0, 1, 3, 6, 13, 15, 17, 31, 35, 36, 37, 45, 51, 96, 120, 123, 124, 125, 126]

    /// Key codes handled through the optional Ctrl→Command Windows layer:
    /// C, X, V, Z, S, P, A, F, W, T, O, N.
    static let ctrlLayerKeys: Set<Int64> = [0, 1, 3, 6, 7, 8, 9, 13, 17, 31, 35, 45]

    /// Resolves a key press to its remapped action, or nil when the exact
    /// key/modifier combination has no enabled shortcut.
    static func action(for keyCode: Int64, flags: CGEventFlags, settings s: ShortcutSettings) -> ShortcutAction? {
        switch keyCode {
        case 36:
            if s.enterToOpen && hasExactModifiers(flags, []) {
                return .synthesizeKey(keyCode: 125, flags: .maskCommand)          // Return → Cmd+Down (open)
            }
            if s.altEnterProperties && hasExactModifiers(flags, .maskAlternate) {
                return .synthesizeKey(keyCode: 34, flags: .maskCommand)           // Alt+Return → Cmd+I (Get Info)
            }
        case 51:
            if s.shiftDeletePermanent && hasExactModifiers(flags, .maskShift) {
                return .synthesizeKey(keyCode: 51, flags: [.maskAlternate, .maskCommand]) // Shift+Delete → Cmd+Opt+Delete
            }
            if s.backspaceUpFolder && hasExactModifiers(flags, []) {
                return .synthesizeKey(keyCode: 126, flags: .maskCommand)          // Delete → Cmd+Up (parent folder)
            }
            if s.deleteToTrash && hasExactModifiers(flags, []) {
                return .synthesizeKey(keyCode: 51, flags: .maskCommand)           // Delete → Cmd+Delete (trash)
            }
        case 15:
            if s.cmdRRename && hasExactModifiers(flags, .maskCommand) {
                return .synthesizeKey(keyCode: 36, flags: [])                     // Cmd+R → Return (rename)
            }
        case 120:
            if s.cmdRRename && hasExactModifiers(flags, []) {
                return .synthesizeKey(keyCode: 36, flags: [])                     // F2 → Return (rename)
            }
        case 7:
            if s.cutAndPaste && hasExactModifiers(flags, .maskCommand) {
                return .beginCut
            }
            // Windows muscle memory: Ctrl+X cuts exactly like Cmd+X.
            if s.cutAndPaste && s.ctrlShortcuts && hasExactModifiers(flags, .maskControl) {
                return .beginCut
            }
        case 8:
            if s.ctrlShortcuts, let mapped = ctrlLayerAction(for: keyCode, flags: flags) {
                return mapped
            }
        case 9:
            if s.cutAndPaste && hasExactModifiers(flags, .maskCommand) {
                return .pasteAfterCut
            }
            // Ctrl+V behaves exactly like Cmd+V, including move-after-cut.
            if s.cutAndPaste && s.ctrlShortcuts && hasExactModifiers(flags, .maskControl) {
                return .pasteAfterCut
            }
        case 126:
            if s.altNavFolders && hasExactModifiers(flags, .maskAlternate) {
                return .synthesizeKey(keyCode: 126, flags: .maskCommand)          // Alt+Up → Cmd+Up (parent)
            }
        case 125:
            if s.altNavFolders && hasExactModifiers(flags, .maskAlternate) {
                return .synthesizeKey(keyCode: 125, flags: .maskCommand)          // Alt+Down → Cmd+Down (open)
            }
        case 123:
            if s.altNavFolders && hasExactModifiers(flags, .maskAlternate) {
                return .synthesizeKey(keyCode: 33, flags: .maskCommand)           // Alt+Left → Cmd+[ (back)
            }
        case 124:
            if s.altNavFolders && hasExactModifiers(flags, .maskAlternate) {
                return .synthesizeKey(keyCode: 30, flags: .maskCommand)           // Alt+Right → Cmd+] (forward)
            }
        case 96:
            if s.f5Refresh && hasExactModifiers(flags, []) {
                return .refreshFinder
            }
        case 37:
            // Ctrl+L is the Explorer address bar: open Go to Folder (Cmd+Shift+G).
            if s.ctrlShortcuts && hasExactModifiers(flags, .maskControl) {
                return .synthesizeKey(keyCode: 5, flags: [.maskCommand, .maskShift])
            }
        default:
            if s.ctrlShortcuts, let mapped = ctrlLayerAction(for: keyCode, flags: flags) {
                return mapped
            }
        }
        return nil
    }

    /// Maps Ctrl(+Shift)+key onto the same key with Command (+Shift). This is
    /// the muscle-memory layer for Windows habits; keys outside the layer keep
    /// their native macOS meaning.
    static func ctrlLayerAction(for keyCode: Int64, flags: CGEventFlags) -> ShortcutAction? {
        guard ctrlLayerKeys.contains(keyCode) else { return nil }
        if hasExactModifiers(flags, .maskControl) {
            return .synthesizeKey(keyCode: keyCode, flags: .maskCommand)
        }
        if hasExactModifiers(flags, [.maskControl, .maskShift]) {
            return .synthesizeKey(keyCode: keyCode, flags: [.maskCommand, .maskShift])
        }
        return nil
    }

    /// True when `flags` carries exactly the required modifiers. Other flags
    /// (fn, caps lock, and any non-modifier state) are deliberately ignored so
    /// fn+F5 or caps lock do not break shortcuts.
    static func hasExactModifiers(_ flags: CGEventFlags, _ required: CGEventFlags) -> Bool {
        let modifierMask: CGEventFlags = [.maskCommand, .maskShift, .maskAlternate, .maskControl]
        return flags.intersection(modifierMask) == required
    }
}

// MARK: - وضعیت برش (Cut)
/// Tracks the Windows-style cut state. The cut is emulated as a copy followed
/// by a move-on-paste, so the state must survive until the matching Cmd+V and
/// must be invalidated if anything else is copied in the meantime.
final class CutState {
    static let shared = CutState()

    private let lock = NSLock()
    private var isActive = false
    private var baselineChangeCount: Int?

    /// Called right after the synthetic Cmd+C is posted. Finder needs a moment
    /// to place the copy on the pasteboard, so the resulting change count is
    /// captured asynchronously and becomes the cut's baseline.
    func mark() {
        lock.lock()
        isActive = true
        baselineChangeCount = nil
        lock.unlock()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.captureBaseline(NSPasteboard.general.changeCount)
        }
    }

    func captureBaseline(_ changeCount: Int) {
        lock.lock()
        defer { lock.unlock() }
        guard isActive else { return }
        baselineChangeCount = changeCount
    }

    /// Consumes the cut state if it is still valid for the current pasteboard.
    /// Returns false when there is no cut, or when another copy replaced the
    /// clipboard after the cut (the caller then pastes normally).
    func consume(currentChangeCount: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard isActive else { return false }
        if let baseline = baselineChangeCount, baseline != currentChangeCount {
            isActive = false
            baselineChangeCount = nil
            return false
        }
        isActive = false
        baselineChangeCount = nil
        return true
    }

    func clear() {
        lock.lock()
        isActive = false
        baselineChangeCount = nil
        lock.unlock()
    }
}

// MARK: - شبیه‌سازی کلید
enum KeySimulator {
    /// Marks events posted by WinFinder so the event tap passes them through
    /// instead of re-intercepting them.
    static let syntheticEventMarker: Int64 = 7777

    @discardableResult
    static func post(keyCode: Int64, flags: CGEventFlags) -> Bool {
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: false) else {
            return false
        }
        keyDown.flags = flags
        keyUp.flags = flags
        keyDown.setIntegerValueField(.eventSourceUserData, value: syntheticEventMarker)
        keyUp.setIntegerValueField(.eventSourceUserData, value: syntheticEventMarker)
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }
}

// MARK: - تشخیص ویرایش متن
enum TextEditingDetector {
    /// True when the focused element is a text field or text area, so normal
    /// typing and text shortcuts must pass through untouched.
    static func isUserEditingText() -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?
        let result = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        guard result == .success, let focusedElement,
              CFGetTypeID(focusedElement) == AXUIElementGetTypeID() else {
            return false
        }
        let element = unsafeBitCast(focusedElement, to: AXUIElement.self)

        var role: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role) == .success,
              let roleName = role as? String else {
            return false
        }
        return roleName == kAXTextFieldRole as String || roleName == kAXTextAreaRole as String
    }
}

// MARK: - رفرش Finder
enum FinderAutomation {
    /// Outcome of one refresh attempt, classified from osascript's result.
    /// `-1743` is the Apple Events permission denial; `-1728` ("can't get
    /// front window") simply means Finder has no open window and is benign.
    enum FinderRefreshOutcome: Equatable {
        case success
        case denied
        case noWindow
        case failed(String)
    }

    static func classify(terminationStatus: Int32, stderr: String) -> FinderRefreshOutcome {
        if terminationStatus == 0 { return .success }
        if stderr.contains("-1743") { return .denied }
        if stderr.contains("-1728") { return .noWindow }
        return .failed(stderr)
    }

    /// Refreshes Finder's front window through osascript on a background
    /// queue, so a slow or unresponsive Finder cannot stall this app. The
    /// callbacks are invoked from a background queue. A watchdog terminates
    /// osascript after five seconds so a hung Finder cannot leak one blocked
    /// thread per press.
    static func refreshFrontWindow(
        onDenied: @escaping () -> Void,
        onFailure: @escaping (String) -> Void,
        onSuccess: @escaping () -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", "tell application \"Finder\" to tell front window to update (get target)"]
            let errorPipe = Pipe()
            process.standardError = errorPipe
            process.standardOutput = FileHandle.nullDevice
            do {
                try process.run()
            } catch {
                onFailure(String(describing: error))
                return
            }

            let stateLock = NSLock()
            var didExit = false
            let pid = process.processIdentifier
            DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                stateLock.lock()
                let finished = didExit
                stateLock.unlock()
                // kill() instead of Process.terminate(): safe even if the
                // process exited between the check and the signal.
                if !finished, pid > 0 {
                    kill(pid, SIGTERM)
                }
            }

            process.waitUntilExit()
            stateLock.lock()
            didExit = true
            stateLock.unlock()

            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8) ?? ""
            switch classify(terminationStatus: process.terminationStatus, stderr: message) {
            case .success, .noWindow:
                onSuccess()
            case .denied:
                onDenied()
            case .failed:
                onFailure(message)
            }
        }
    }
}
