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
    var f5AllWindows = false
    var backspaceUpFolder = false
    var ctrlShortcuts = true
}

extension ShortcutSettings {
    /// Single source of truth for every shortcut toggle's defaults key and
    /// default value. The compiled-in registration, the settings reset, the
    /// export/import payload, and the live cheat-sheet all read from here, so
    /// a new toggle only needs a property in the struct above plus one row in
    /// this table.
    static let keysAndDefaults: [(key: String, value: Bool)] = [
        ("enterToOpen", true),
        ("deleteToTrash", true),
        ("shiftDeletePermanent", true),
        ("cmdRRename", true),
        ("cutAndPaste", true),
        ("altEnterProperties", true),
        ("altNavFolders", true),
        ("f5Refresh", true),
        ("f5AllWindows", false),
        ("backspaceUpFolder", false),
        ("ctrlShortcuts", true),
    ]

    /// The same table as a plain dictionary for `UserDefaults.register`.
    static var defaultValues: [String: Any] {
        Dictionary(uniqueKeysWithValues: keysAndDefaults.map { ($0.key, $0.value) })
    }

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
            f5AllWindows: defaults.bool(forKey: "f5AllWindows"),
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
    /// Copy (8) is observed only to invalidate a stale cut state; 76 is the
    /// numeric-keypad Enter, which must open exactly like the main Enter.
    static let watchedKeys: Set<Int64> = [7, 8, 9, 0, 1, 3, 6, 13, 15, 17, 31, 35, 36, 37, 45, 51, 76, 96, 120, 123, 124, 125, 126]

    /// Key codes handled through the optional Ctrl→Command Windows layer:
    /// C, X, V, Z, S, P, A, F, W, T, O, N.
    static let ctrlLayerKeys: Set<Int64> = [0, 1, 3, 6, 7, 8, 9, 13, 17, 31, 35, 45]

    /// Resolves a key press to its remapped action, or nil when the exact
    /// key/modifier combination has no enabled shortcut.
    static func action(for keyCode: Int64, flags: CGEventFlags, settings s: ShortcutSettings) -> ShortcutAction? {
        switch keyCode {
        case 36, 76:
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

    /// Posted (from any thread) whenever the cut state is marked, cleared, or
    /// consumed. The menu bar uses it to show a "cut pending" indicator.
    static let didChangeNotification = Notification.Name("com.winfinderpro.cutstate.changed")

    /// A fast Finder writes the copy onto the pasteboard almost immediately;
    /// a slow one may take hundreds of milliseconds. Poll briefly instead of
    /// trusting a fixed delay, so the baseline is captured exactly when the
    /// copy lands — never before (which would miss it) or after a second
    /// unrelated copy (which would invalidate a legitimate cut).
    private static let baselinePollInterval: TimeInterval = 0.05
    private static let maxBaselinePolls = 40

    private let lock = NSLock()
    private var isActive = false
    private var baselineChangeCount: Int?
    private var preCutChangeCount: Int?
    private var pollGeneration = 0

    /// True while a cut is pending. Read from the menu bar on the main thread;
    /// safe from anywhere thanks to the lock.
    var active: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isActive
    }

    /// Called right after the synthetic Cmd+C is posted. The change count
    /// before the copy is recorded, then the pasteboard is polled until the
    /// copy actually lands; the new change count becomes the cut's baseline.
    func mark() {
        lock.lock()
        isActive = true
        baselineChangeCount = nil
        preCutChangeCount = NSPasteboard.general.changeCount
        pollGeneration += 1
        let generation = pollGeneration
        lock.unlock()
        notify()
        scheduleBaselineCapture(generation: generation, attempt: 0)
    }

    private func scheduleBaselineCapture(generation: Int, attempt: Int) {
        guard attempt < Self.maxBaselinePolls else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.baselinePollInterval) { [weak self] in
            guard let self else { return }
            self.lock.lock()
            let stillActive = self.isActive && self.pollGeneration == generation && self.baselineChangeCount == nil
            let preCut = self.preCutChangeCount
            self.lock.unlock()
            guard stillActive, let preCut else { return }
            let current = NSPasteboard.general.changeCount
            guard current != preCut else {
                self.scheduleBaselineCapture(generation: generation, attempt: attempt + 1)
                return
            }
            self.captureBaseline(current)
        }
    }

    /// Installs an explicit baseline. Public for the offline logic tests; the
    /// app itself relies on the polling capture above.
    func captureBaseline(_ changeCount: Int) {
        lock.lock()
        defer { lock.unlock() }
        guard isActive else { return }
        baselineChangeCount = changeCount
    }

    private func notify() {
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    /// Consumes the cut state if it is still valid for the current pasteboard.
    /// Returns false when there is no cut, or when another copy replaced the
    /// clipboard after the cut (the caller then pastes normally).
    func consume(currentChangeCount: Int) -> Bool {
        lock.lock()
        guard isActive else {
            lock.unlock()
            return false
        }
        let invalidated: Bool
        if let baseline = baselineChangeCount, baseline != currentChangeCount {
            // Another copy replaced the clipboard after the cut: the state is
            // spent, and the paste falls through as a normal paste.
            isActive = false
            baselineChangeCount = nil
            invalidated = true
        } else {
            isActive = false
            baselineChangeCount = nil
            invalidated = false
        }
        preCutChangeCount = nil
        pollGeneration += 1
        lock.unlock()
        notify()
        return !invalidated
    }

    func clear() {
        lock.lock()
        let wasActive = isActive
        isActive = false
        baselineChangeCount = nil
        preCutChangeCount = nil
        pollGeneration += 1
        lock.unlock()
        if wasActive { notify() }
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
    /// The focused-element AX query runs on the tap thread for every initial
    /// key press. A very short cache absorbs the cost of fast typing (where
    /// the focused element cannot change between adjacent keystrokes) without
    /// materially delaying a just-changed focus target.
    private static let cacheInterval: TimeInterval = 0.12
    private static let lock = NSLock()
    private static var cached: (result: Bool, date: Date)?

    /// True when the focused element is a text field or text area, so normal
    /// typing and text shortcuts must pass through untouched.
    static func isUserEditingText() -> Bool {
        let now = Date()
        lock.lock()
        let cachedResult = cached.flatMap { now.timeIntervalSince($0.date) < cacheInterval ? $0.result : nil }
        lock.unlock()
        if let cachedResult { return cachedResult }

        let detected = detectUserEditingText()
        lock.lock()
        cached = (detected, now)
        lock.unlock()
        return detected
    }

    private static func detectUserEditingText() -> Bool {
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
/// Minimal lock-guarded boolean shared between a task and its watchdog
/// closure; satisfies the Sendable-capture checking a plain `var` trips.
final class AtomicFlag {
    private let lock = NSLock()
    private var value = false

    func set() {
        lock.lock()
        value = true
        lock.unlock()
    }

    func get() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

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
        refreshAllWindows: Bool = false,
        onDenied: @escaping () -> Void,
        onFailure: @escaping (String) -> Void,
        onSuccess: @escaping () -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            // One subprocess handles every case: the front window, every open
            // window (the optional F5-all toggle), and a desktop fallback when
            // Finder has no window at all. A missing front window (-1728) is
            // no longer treated as "nothing to do".
            let refreshScript = """
            on run argv
                set refreshAllWindows to ((count of argv) > 0) and ((item 1 of argv) is "all")
                tell application "Finder"
                    try
                        if refreshAllWindows then
                            repeat with w in windows
                                try
                                    update w
                                end try
                            end repeat
                        else
                            tell front window to update (get target)
                        end if
                    on error number -1728
                        try
                            update desktop
                        end try
                    end try
                end tell
            end run
            """
            process.arguments = refreshAllWindows
                ? ["-e", refreshScript, "all"]
                : ["-e", refreshScript]
            let errorPipe = Pipe()
            process.standardError = errorPipe
            process.standardOutput = FileHandle.nullDevice
            do {
                try process.run()
            } catch {
                onFailure(String(describing: error))
                return
            }

            let didExit = AtomicFlag()
            let pid = process.processIdentifier
            DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                // kill() instead of Process.terminate(): safe even if the
                // process exited between the check and the signal.
                if !didExit.get(), pid > 0 {
                    kill(pid, SIGTERM)
                }
            }

            process.waitUntilExit()
            didExit.set()

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
