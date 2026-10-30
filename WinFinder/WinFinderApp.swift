import SwiftUI
import Cocoa
import ApplicationServices
import ServiceManagement
import Combine

// MARK: - ساختار اصلی برنامه و منوبار
@main
struct WinFinderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Window(L10n.tr(UserDefaults.standard.string(forKey: "appLanguage") ?? "en", "window.title"), id: "main-settings") {
            MainSettingsView()
                .environmentObject(appDelegate)
        }
        .windowResizability(.contentMinSize)

        Window(L10n.tr(UserDefaults.standard.string(forKey: "appLanguage") ?? "en", "about.title"), id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)

        MenuBarExtra {
            MenuBarStatusView()
                .environmentObject(appDelegate)
        } label: {
            MenuBarIconView(appDelegate: appDelegate)
        }
    }
}

// MARK: - هسته مدیریت رویدادهای پس‌زمینه و خروج از داک

/// Thread-safe holder for the event-tap run loop: written once by the tap
/// thread, read from the main thread during teardown. Deliberately non-generic
/// — a generic class's destroying destructor trips a SIL inliner crash in some
/// Swift 6.2 toolchains during Release optimization.
final class TapRunLoopHolder {
    private let lock = NSLock()
    private var runLoop: CFRunLoop?

    func set(_ value: CFRunLoop?) {
        lock.lock()
        runLoop = value
        lock.unlock()
    }

    func get() -> CFRunLoop? {
        lock.lock()
        defer { lock.unlock() }
        return runLoop
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    static private(set) var shared: AppDelegate?

    enum EventTapState: String, Equatable {
        case stopped
        case waitingForAccessibility
        case starting
        case running
        case retrying
        case failed
    }

    /// User-visible issue categories. Raw technical messages go to the log;
    /// the UI shows a localized explanation with a fix-it action.
    enum AppIssue: Hashable {
        case eventTapCreation(String)
        case finderAutomationDenied
        case finderRefreshFailed(String)
    }

    var eventTap: CFMachPort?
    @Published var isAccessGranted: Bool = false
    @Published private(set) var eventTapState: EventTapState = .stopped
    @Published private(set) var activeIssues: [AppIssue] = []
    @Published private(set) var isFinderAutomationDenied = false
    @Published private(set) var isPaused = false

    private var permissionPollTimer: Timer?
    private var permissionPollAttempts = 0
    private var tapRetryWorkItem: DispatchWorkItem?
    private var tapRetryAttempts = 0
    private static let maxTapRetryAttempts = 3
    private var isStopping = false

    // In-place re-enables are bounded: a tap whose callback keeps timing out
    // (for example, a hung Accessibility subsystem) must degrade to the
    // bounded retry instead of looping hang -> re-enable forever.
    private static let maxInPlaceReEnables = 5
    private static let inPlaceReEnableWindow: TimeInterval = 60
    private var inPlaceReEnableCount = 0
    private var lastInPlaceReEnable: Date?
    private let reEnableLock = NSLock()

    // The event tap runs on its own run loop: if this app ever stalls, the
    // whole system's keyboard input must not stall with it.
    private var tapThread: Thread?
    private let tapRunLoop = TapRunLoopHolder()

    // Pending auto-resume for the "pause for an hour" menu action.
    private var scheduledResumeWorkItem: DispatchWorkItem?

    // Kernel-held single-instance lock (flock): released automatically when
    // the process dies, so there is no stale-lock state and no TOCTOU window.
    private var singleInstanceFD: Int32 = -1

    // Launch-source detection: a user launch (Finder, Dock, `open`) delivers
    // the open-application Apple Event; a login-item launch does not. Used to
    // keep login launches a quiet menu-bar agent without a settings window.
    private var receivedOpenApplicationEvent = false
    private(set) var isLaunchedAtLogin = false

    // SwiftUI's openWindow action captured from the menu-bar icon view, so the
    // delegate can open the settings scene outside the SwiftUI hierarchy.
    private var openWindowAction: OpenWindowAction?

    override init() {
        super.init()
        AppDelegate.shared = self
    }

    // Keep login/launch instances as a menu-bar agent before any window is shown.
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleOpenApplicationEvent(_:withReplyEvent:)),
            forEventClass: kCoreEventClass,
            andEventID: kAEOpenApplication
        )
    }

    @objc private func handleOpenApplicationEvent(_ event: NSAppleEventDescriptor, withReplyEvent reply: NSAppleEventDescriptor) {
        receivedOpenApplicationEvent = true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Two copies would both install an event tap and double every action.
        guard acquireSingleInstanceLock() else {
            DispatchQueue.main.async { NSApp.terminate(nil) }
            return
        }

        let defaults = UserDefaults.standard
        let hadPersistentLaunchAtLoginPreference =
            defaults.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "")?["launchAtLogin"] != nil

        defaults.register(defaults: [
            "enterToOpen": true,
            "deleteToTrash": true,
            "shiftDeletePermanent": true,
            "cmdRRename": true,
            "cutAndPaste": true,
            "altEnterProperties": true,
            "altNavFolders": true,
            "f5Refresh": true,
            "backspaceUpFolder": false,
            "ctrlShortcuts": true,
            "launchAtLogin": true,
            "appLanguage": "en"
        ])

        // New installations should behave like a normal menu-bar utility and
        // start at login. An existing explicit opt-out is respected.
        if !hadPersistentLaunchAtLoginPreference {
            defaults.set(true, forKey: "launchAtLogin")
        }
        if defaults.bool(forKey: "launchAtLogin") && !LaunchAtLoginState.isRegistered {
            if isRunningFromPreferredLocation {
                do {
                    try SMAppService.mainApp.register()
                } catch {
                    NSLog("WinFinder: launch-at-login registration failed: \(error)")
                }
            } else {
                NSLog("WinFinder: skipping launch-at-login registration; the app is not in \(Self.preferredInstallPath)")
            }
        }
        // The preference stores the user's intent and is deliberately NOT
        // overwritten with the service state: a transient registration failure
        // must not silently turn the user's opt-in off forever.

        // NSWorkspace's center is only for workspace notifications. Application
        // lifecycle notifications belong to NotificationCenter.default.
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(checkAccessSilently),
            name: NSApplication.didBecomeActiveNotification,
            object: NSApp
        )

        // The first check happens after observers are installed so an access
        // change made while launching cannot be missed.
        checkAccessSilently()

        // Decide the launch context once the open-application Apple Event had
        // a chance to arrive. Login launches must not pop the settings window.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.finishLaunchContextDecision()
        }
    }

    deinit {
        permissionPollTimer?.invalidate()
        tapRetryWorkItem?.cancel()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
        stopKeyInterceptor()
    }

    // بسته نشدن برنامه هنگام بستن پنجره
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        isStopping = true
        permissionPollTimer?.invalidate()
        tapRetryWorkItem?.cancel()
        scheduledResumeWorkItem?.cancel()
        stopKeyInterceptor()
    }

    // Closing the settings window must not quit the menu-bar utility. A real
    // Quit request is still allowed so macOS shutdown/logout cannot be blocked.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        return .terminateNow
    }

    // MARK: اجرای همزمان دو نسخه

    /// True when this copy owns the kernel single-instance lock. The lock is
    /// acquired atomically (flock) and released by the kernel on process death,
    /// so two simultaneously launching copies can never both believe they are
    /// alone.
    private func acquireSingleInstanceLock() -> Bool {
        let lockPath = (NSTemporaryDirectory() as NSString).appendingPathComponent("com.winfinderpro.app.instance.lock")
        let fd = open(lockPath, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard fd >= 0 else {
            NSLog("WinFinder: could not open the single-instance lock file; continuing permissively.")
            return true
        }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.winfinderpro.app"
            let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
                .filter { $0.processIdentifier != NSRunningApplication.current.processIdentifier }
            NSLog("WinFinder: another instance is already running\(others.first.map { " (pid \($0.processIdentifier))" } ?? ""); quitting this copy.")
            close(fd)
            return false
        }
        // Deliberately never closed: the descriptor is the lock.
        singleInstanceFD = fd
        return true
    }

    // MARK: مسیر نصب

    static let preferredInstallPath = "/Applications/WinFinder.app"

    /// Registering a login item pins the app's current location; anything
    /// outside /Applications breaks as soon as the app is moved.
    var isRunningFromPreferredLocation: Bool {
        Bundle.main.bundleURL.standardizedFileURL.path == Self.preferredInstallPath
    }

    // MARK: تشخیص اجرای هنگام لاگین و آموزش اولیه

    private func finishLaunchContextDecision() {
        isLaunchedAtLogin = !receivedOpenApplicationEvent
        let settingsTitle = L10n.tr(UserDefaults.standard.string(forKey: "appLanguage") ?? "en", "window.title")
        let settingsWindowVisible = NSApp.windows.contains { $0.isVisible && $0.title == settingsTitle }
        if isLaunchedAtLogin {
            NSLog("WinFinder: launched at login (no open-application event); suppressing settings window")
            closeAutoOpenedSettingsWindow()
        } else {
            NSLog("WinFinder: user launch detected")
            if !isAccessGranted {
                // A user launch while accessibility is missing means the app
                // cannot do its job: ask for the permission right away.
                requestAccessManually()
            }
            // SwiftUI does not auto-open Window scenes in a menu-bar agent, so
            // a user launch must show the settings window explicitly.
            if !settingsWindowVisible {
                showSettingsWindow()
            }
        }
    }

    private func closeAutoOpenedSettingsWindow() {
        let title = L10n.tr(UserDefaults.standard.string(forKey: "appLanguage") ?? "en", "window.title")
        for window in NSApp.windows where window.isVisible && window.title == title {
            window.close()
        }
    }

    func registerOpenWindowAction(_ action: OpenWindowAction) {
        openWindowAction = action
    }

    /// Activates the app with the API that is current for the OS in use.
    static func activateApp() {
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    /// Opens the settings window from AppKit context and brings it to the
    /// front despite the accessory activation policy.
    func showSettingsWindow() {
        if Thread.isMainThread {
            performShowWindow(id: "main-settings")
        } else {
            DispatchQueue.main.async { [weak self] in self?.performShowWindow(id: "main-settings") }
        }
    }

    /// Opens the small About window from the menu bar.
    func showAboutWindow() {
        if Thread.isMainThread {
            performShowWindow(id: "about")
        } else {
            DispatchQueue.main.async { [weak self] in self?.performShowWindow(id: "about") }
        }
    }

    private func performShowWindow(id: String) {
        if let action = openWindowAction {
            action(id: id)
        } else if id == "main-settings",
                  let window = NSApp.windows.first(where: { $0.title == L10n.tr(UserDefaults.standard.string(forKey: "appLanguage") ?? "en", "window.title") }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            NSLog("WinFinder: cannot open window '\(id)' (no open-window action registered yet)")
            return
        }
        Self.activateApp()
    }

    // MARK: توقف موقت میانبرها

    func setPaused(_ paused: Bool) {
        guard isPaused != paused else { return }
        isPaused = paused
        if paused {
            stopKeyInterceptor()
        } else {
            scheduledResumeWorkItem?.cancel()
            scheduledResumeWorkItem = nil
            checkAccessSilently()
        }
    }

    /// Menu-bar convenience: pause now and resume automatically after an hour.
    func pauseForOneHour() {
        setPaused(true)
        scheduledResumeWorkItem?.cancel()
        let resume = DispatchWorkItem { [weak self] in
            self?.setPaused(false)
        }
        scheduledResumeWorkItem = resume
        DispatchQueue.main.asyncAfter(deadline: .now() + 3600, execute: resume)
    }

    /// True when an in-place tap re-enable is still allowed. Consecutive
    /// re-enables are counted inside a rolling window; a tap that keeps
    /// timing out falls back to the bounded replacement retry.
    private func allowInPlaceReEnable() -> Bool {
        reEnableLock.lock()
        defer { reEnableLock.unlock() }
        let now = Date()
        if let last = lastInPlaceReEnable, now.timeIntervalSince(last) > Self.inPlaceReEnableWindow {
            inPlaceReEnableCount = 0
        }
        guard inPlaceReEnableCount < Self.maxInPlaceReEnables else { return false }
        inPlaceReEnableCount += 1
        lastInPlaceReEnable = now
        return true
    }

    private func resetInPlaceReEnables() {
        reEnableLock.lock()
        inPlaceReEnableCount = 0
        lastInPlaceReEnable = nil
        reEnableLock.unlock()
    }

    // Outcome of the initial (non-autorepeat) press of a key: whether it was
    // intercepted for a shortcut or passed through to a text field. Autorepeat
    // events of the same key reuse this decision. Guarded by a lock because
    // the tap thread writes and reads it around teardown on the main thread.
    private struct KeyDecision {
        let intercepted: Bool
        let date: Date
    }

    private static var lastKeyDecision: (keyCode: Int64, decision: KeyDecision)?
    private static let keyDecisionLock = NSLock()

    private static func recordKeyDecision(keyCode: Int64, intercepted: Bool) {
        keyDecisionLock.lock()
        lastKeyDecision = (keyCode, KeyDecision(intercepted: intercepted, date: Date()))
        keyDecisionLock.unlock()
    }

    private static func cachedKeyDecision(keyCode: Int64) -> Bool? {
        keyDecisionLock.lock()
        defer { keyDecisionLock.unlock() }
        guard let entry = lastKeyDecision,
              entry.keyCode == keyCode,
              Date().timeIntervalSince(entry.decision.date) < 1.5 else {
            return nil
        }
        return entry.decision.intercepted
    }

    @objc func handleWake() {
        // A wake is an explicit recovery signal; allow bounded replacement
        // attempts for a tap that was disabled while the machine slept.
        tapRetryAttempts = 0
        if eventTap == nil, eventTapState == .failed {
            eventTapState = .stopped
        }
        checkAccessSilently()
    }

    @objc func checkAccessSilently() {
        let trusted = AXIsProcessTrusted()

        guard trusted else {
            isAccessGranted = false
            permissionPollTimer?.invalidate()
            permissionPollTimer = nil
            CutState.shared.clear()
            stopKeyInterceptor()
            eventTapState = .waitingForAccessibility
            return
        }

        isAccessGranted = true
        permissionPollTimer?.invalidate()
        permissionPollTimer = nil

        if eventTap == nil, tapRetryWorkItem == nil, !isPaused {
            // A failed retry can be restarted by a real lifecycle event
            // (activation, wake, or an explicit permission request), but never
            // by a permanent background polling loop.
            if eventTapState == .failed {
                tapRetryAttempts = 0
                eventTapState = .stopped
            }
            startKeyInterceptor()
        } else if let tap = eventTap, !CGEvent.tapIsEnabled(tap: tap) {
            scheduleTapRetry(reason: "event tap is disabled")
        }
    }

    func requestAccessManually() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options)
        tapRetryAttempts = 0
        if eventTap == nil, eventTapState == .failed {
            eventTapState = .stopped
        }
        checkAccessSilently()

        // The prompt opens System Settings in another process. Poll for a full
        // minute so returning from that screen activates the tap without
        // requiring a second click in this app.
        permissionPollAttempts = 0
        permissionPollTimer?.invalidate()
        permissionPollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            self.permissionPollAttempts += 1
            self.checkAccessSilently()
            if self.isAccessGranted || self.permissionPollAttempts >= 120 {
                timer.invalidate()
                self.permissionPollTimer = nil
            }
        }
    }

    // MARK: مدیریت event tap

    func startKeyInterceptor() {
        guard !isStopping, eventTap == nil else { return }
        guard AXIsProcessTrusted() else {
            eventTapState = .waitingForAccessibility
            return
        }

        eventTapState = .starting
        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                return AppDelegate.handleKeyEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: nil
        ) else {
            reportIssue(.eventTapCreation("CGEvent.tapCreate returned nil"))
            eventTapState = .failed
            scheduleTapRetry(reason: "event tap creation failed")
            return
        }

        guard let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            reportIssue(.eventTapCreation("Could not create the event tap run-loop source"))
            eventTapState = .failed
            scheduleTapRetry(reason: "run-loop source creation failed")
            return
        }

        let thread = Thread { [weak self] in
            guard let self else { return }
            let runLoop = CFRunLoopGetCurrent()
            self.tapRunLoop.set(runLoop)
            CFRunLoopAddSource(runLoop, runLoopSource, .commonModes)
            while !Thread.current.isCancelled {
                RunLoop.current.run(mode: .default, before: Date.distantFuture)
            }
        }
        thread.name = "WinFinder EventTap"
        thread.qualityOfService = .userInteractive

        eventTap = tap
        tapThread = thread
        thread.start()
        CGEvent.tapEnable(tap: tap, enable: true)
        tapRetryAttempts = 0
        resetInPlaceReEnables()
        activeIssues.removeAll { issue in
            if case .eventTapCreation = issue { return true }
            return false
        }
        eventTapState = .running
    }

    static func handleKeyEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // Recover in place first: re-enabling keeps the tap warm and loses
            // no keystrokes. In-place recovery is bounded, and a tap whose
            // Accessibility permission was revoked is dropped cleanly instead.
            if let shared = AppDelegate.shared {
                // Cheap permission check first so a revoked Accessibility
                // grant does not consume the in-place recovery budget.
                if !AXIsProcessTrusted() {
                    DispatchQueue.main.async { shared.checkAccessSilently() }
                    return Unmanaged.passUnretained(event)
                }
                guard shared.allowInPlaceReEnable() else {
                    DispatchQueue.main.async {
                        AppDelegate.shared?.scheduleTapRetry(reason: "event tap disabled: \(type)")
                    }
                    return Unmanaged.passUnretained(event)
                }
                if let tap = shared.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                    if CGEvent.tapIsEnabled(tap: tap) {
                        return Unmanaged.passUnretained(event)
                    }
                }
            }
            DispatchQueue.main.async {
                AppDelegate.shared?.scheduleTapRetry(reason: "event tap disabled: \(type)")
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else { return Unmanaged.passUnretained(event) }

        if event.getIntegerValueField(.eventSourceUserData) == KeySimulator.syntheticEventMarker {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard ShortcutResolver.watchedKeys.contains(keyCode) else {
            return Unmanaged.passUnretained(event)
        }

        let flags = event.flags

        // Cmd+C invalidates our synthetic cut state in every app, before any
        // other decision is made.
        if keyCode == 8 && ShortcutResolver.hasExactModifiers(flags, .maskCommand) {
            CutState.shared.clear()
        }

        let settings = ShortcutSettings(defaults: .standard)
        guard let action = ShortcutResolver.action(for: keyCode, flags: flags, settings: settings) else {
            return Unmanaged.passUnretained(event)
        }

        // Custom shortcuts only apply to Finder; everywhere else the keys
        // keep their native meaning.
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              frontApp.bundleIdentifier == "com.apple.finder" else {
            CutState.shared.clear()
            return Unmanaged.passUnretained(event)
        }

        // Autorepeats decide from the cached outcome of the initial press of
        // this same key: presses that went into a text field keep repeating
        // natively (holding Backspace must keep erasing), intercepted presses
        // are single-shot so Finder never sees the plain key's repeat. The
        // cache avoids an AX query per repeat event; a cache miss falls back
        // to the explicit check.
        if event.getIntegerValueField(.keyboardEventAutorepeat) != 0 {
            switch cachedKeyDecision(keyCode: keyCode) {
            case false:
                return Unmanaged.passUnretained(event)
            case true:
                return action == .pasteAfterCut ? Unmanaged.passUnretained(event) : nil
            case nil:
                return TextEditingDetector.isUserEditingText()
                    ? Unmanaged.passUnretained(event)
                    : (action == .pasteAfterCut ? Unmanaged.passUnretained(event) : nil)
            }
        }

        // Documented thread-safety note: this runs on the dedicated tap
        // thread. The AX lookup below and the read-only getters used here
        // (NSWorkspace.frontmostApplication, NSPasteboard.changeCount) are not
        // formally guaranteed thread-safe, but they are the established,
        // read-only pattern for event-tap utilities and never mutate state.
        let isTextEditing = TextEditingDetector.isUserEditingText()
        recordKeyDecision(keyCode: keyCode, intercepted: !isTextEditing)
        guard !isTextEditing else {
            return Unmanaged.passUnretained(event)
        }

        switch action {
        case .synthesizeKey(let syntheticKeyCode, let syntheticFlags):
            // A synthesized ⌘C (from Ctrl+C) is itself a user copy action:
            // invalidate any pending cut immediately instead of waiting for
            // the pasteboard baseline capture to catch up.
            if syntheticKeyCode == 8 && syntheticFlags == .maskCommand {
                CutState.shared.clear()
            }
            if !KeySimulator.post(keyCode: syntheticKeyCode, flags: syntheticFlags) {
                AppDelegate.shared?.reportIssue(.eventTapCreation("Could not create synthetic key event for key code \(syntheticKeyCode)"))
                return Unmanaged.passUnretained(event)
            }
        case .beginCut:
            if KeySimulator.post(keyCode: 8, flags: .maskCommand) {
                CutState.shared.mark()
            } else {
                return Unmanaged.passUnretained(event)
            }
        case .pasteAfterCut:
            if CutState.shared.consume(currentChangeCount: NSPasteboard.general.changeCount) {
                if !KeySimulator.post(keyCode: 9, flags: [.maskAlternate, .maskCommand]) {
                    CutState.shared.clear()
                    return Unmanaged.passUnretained(event)
                }
            } else {
                // No valid cut (or the clipboard changed since the cut):
                // fall back to a normal paste.
                return Unmanaged.passUnretained(event)
            }
        case .refreshFinder:
            FinderAutomation.refreshFrontWindow(
                onDenied: { AppDelegate.shared?.reportIssue(.finderAutomationDenied) },
                onFailure: { AppDelegate.shared?.reportIssue(.finderRefreshFailed($0)) },
                onSuccess: { AppDelegate.shared?.finderAutomationSucceeded() }
            )
        }
        return nil
    }

    private func scheduleTapRetry(reason: String) {
        guard !isStopping,
              tapRetryWorkItem == nil,
              tapRetryAttempts < Self.maxTapRetryAttempts else { return }
        tapRetryAttempts += 1
        eventTapState = .retrying
        NSLog("WinFinder: \(reason)")

        // Remove the disabled tap before creating a replacement. This avoids
        // leaving two callbacks registered after timeout/wake recovery.
        stopKeyInterceptor()
        eventTapState = .retrying

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.tapRetryWorkItem = nil
            self.eventTapState = .stopped
            self.checkAccessSilently()
        }
        tapRetryWorkItem = workItem
        let delay = min(pow(2.0, Double(tapRetryAttempts - 1)) * 0.25, 2.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func stopKeyInterceptor() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            eventTap = nil
        }
        tapThread?.cancel()
        if let runLoop = tapRunLoop.get() {
            CFRunLoopStop(runLoop)
        }
        tapThread = nil
        tapRunLoop.set(nil)
        CutState.shared.clear()
        if isAccessGranted {
            eventTapState = .stopped
        }
    }

    // MARK: خطاها و وضعیت

    func reportIssue(_ issue: AppIssue) {
        NSLog("WinFinder: \(issue.logText)")
        if Thread.isMainThread {
            applyIssue(issue)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.applyIssue(issue)
            }
        }
    }

    private func applyIssue(_ issue: AppIssue) {
        // Keep every distinct unresolved problem visible; the banner can show
        // several at once instead of the latest overwriting the rest.
        if !activeIssues.contains(issue) {
            activeIssues.append(issue)
            if activeIssues.count > 4 {
                activeIssues.removeFirst(activeIssues.count - 4)
            }
        }
        if issue == .finderAutomationDenied {
            isFinderAutomationDenied = true
        }
    }

    func finderAutomationSucceeded() {
        DispatchQueue.main.async { [weak self] in
            self?.isFinderAutomationDenied = false
            // A successful (or benign) refresh proves the pipeline works:
            // stale transient-failure banners must not survive it.
            self?.activeIssues.removeAll { issue in
                if issue == .finderAutomationDenied { return true }
                if case .finderRefreshFailed = issue { return true }
                return false
            }
        }
    }
}

extension AppDelegate.AppIssue {
    var logText: String {
        switch self {
        case .eventTapCreation(let message):
            return message
        case .finderAutomationDenied:
            return "Finder refresh denied: Apple Events permission missing (-1743)"
        case .finderRefreshFailed(let message):
            return "Finder refresh failed: \(message)"
        }
    }
}

// MARK: - وضعیت Launch at Login
enum LaunchAtLoginState {
    static var isRegistered: Bool {
        switch SMAppService.mainApp.status {
        case .enabled, .requiresApproval:
            return true
        case .notRegistered, .notFound:
            return false
        @unknown default:
            return false
        }
    }
}
