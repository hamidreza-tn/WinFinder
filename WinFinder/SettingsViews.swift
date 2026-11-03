import SwiftUI
import ServiceManagement
import UniformTypeIdentifiers

// MARK: - ثابت‌های طراحی
/// Single source for spacing and corner radii so the UI stays consistent.
private enum Design {
    static let cornerRadius: CGFloat = 10
    static let cardPadding: CGFloat = 12
    static let groupSpacing: CGFloat = 16
    static let rowSpacing: CGFloat = 10
}

/// Brand accent (from the AccentColor asset) used by switches, buttons, and
/// the header mark.
private enum Brand {
    static let accent = Color("AccentColor")

    static var headerGradient: LinearGradient {
        LinearGradient(
            colors: [accent.opacity(0.85), accent],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - شناسه‌های پنجره‌ها
/// Stable window identities used by the AppKit side to find the windows it
/// needs. Localized titles change with the interface language, so matching
/// must never rely on the title; the title match is kept only as a fallback
/// for the brief moment before a SwiftUI window has installed its identifier.
enum WinFinderWindowID {
    static let settings = NSUserInterfaceItemIdentifier("com.winfinderpro.window.settings")
    static let about = NSUserInterfaceItemIdentifier("com.winfinderpro.window.about")
}

/// Installs a stable identifier on the enclosing NSWindow as soon as SwiftUI
/// moves the view into it. Used as an invisible background on each scene root.
struct WindowIdentifierSetter: NSViewRepresentable {
    let id: NSUserInterfaceItemIdentifier

    func makeNSView(context: Context) -> IdentifyingView { IdentifyingView(targetID: id) }

    func updateNSView(_ nsView: IdentifyingView, context: Context) {
        // The identifier never changes for a scene; reassert it in case the
        // view has moved between windows since makeNSView.
        nsView.window?.identifier = id
    }

    final class IdentifyingView: NSView {
        // Not named `identifier`: NSView already exposes one of that name.
        let targetID: NSUserInterfaceItemIdentifier

        init(targetID: NSUserInterfaceItemIdentifier) {
            self.targetID = targetID
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) {
            fatalError("not used")
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.identifier = targetID
        }
    }
}

// MARK: - لینک مستقیم به بخش‌های System Settings
enum SystemSettingsOpener {
    static func openAccessibility() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    static func openAutomation() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - ابزارهای مشترک نمایش
/// The "2.4 (6)" style version string shown in Settings, Diagnostics, and About.
func appVersionText() -> String {
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
    return "\(version) (\(build))"
}

/// The currently enabled shortcuts as (keycap, description) rows. Shared by
/// the Settings cheat-sheet and the compact menu-bar list. Reads through the
/// shared ShortcutSettings snapshot so the guide can never disagree with what
/// the event tap actually applies.
func activeShortcutRows(language: String) -> [(keys: String, description: String)] {
    let settings = ShortcutSettings(defaults: .standard)

    var rows: [(String, String)] = []
    if settings.enterToOpen {
        rows.append(("Enter", L10n.tr(language, "cs.open")))
    }
    if settings.backspaceUpFolder {
        rows.append(("Delete", L10n.tr(language, "cs.parentFolder")))
    } else if settings.deleteToTrash {
        rows.append(("Delete", L10n.tr(language, "cs.trash")))
    }
    if settings.shiftDeletePermanent {
        rows.append(("Shift + Delete", L10n.tr(language, "cs.permanentDelete")))
    }
    if settings.cmdRRename {
        rows.append(("Cmd + R  /  F2", L10n.tr(language, "cs.rename")))
    }
    if settings.cutAndPaste {
        rows.append(("Cmd + X  /  Cmd + V", L10n.tr(language, "cs.cutPaste")))
    }
    if settings.altEnterProperties {
        rows.append(("Alt + Enter", L10n.tr(language, "cs.properties")))
    }
    if settings.altNavFolders {
        rows.append(("Alt + ↑  /  Alt + ↓", L10n.tr(language, "cs.navUpDown")))
        rows.append(("Alt + ←  /  Alt + →", L10n.tr(language, "cs.navBackForward")))
    }
    if settings.f5Refresh {
        rows.append(("F5", L10n.tr(language, "cs.refresh")))
    }
    if settings.ctrlShortcuts {
        rows.append(("Ctrl + C / X / V / Z / S / P / A / F / N / W / T / O", L10n.tr(language, "cs.ctrlLayer")))
        rows.append(("Ctrl + L", L10n.tr(language, "cs.ctrlGoto")))
        rows.append(("Ctrl + Shift + N", L10n.tr(language, "cs.ctrlNewFolder")))
    }
    return rows
}

/// Card look for settings groups: rounded panel, hairline border, group label
/// as a section heading instead of the stock inset GroupBox chrome.
struct CardGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: Design.rowSpacing) {
            configuration.label
                .font(.subheadline.weight(.semibold))
            configuration.content
        }
        .padding(Design.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Design.cornerRadius, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Design.cornerRadius, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.14), lineWidth: 1)
        )
    }
}

extension AppDelegate.AppIssue {
    func displayText(_ language: String) -> String {
        switch self {
        case .eventTapCreation:
            return L10n.tr(language, "issue.tapCreation")
        case .syntheticKeyFailed:
            return L10n.tr(language, "issue.syntheticKey")
        case .finderAutomationDenied:
            return L10n.tr(language, "issue.automationDenied")
        case .finderRefreshFailed:
            return L10n.tr(language, "issue.refreshFailed")
        }
    }
}

// MARK: - رابط گرافیکی تنظیمات
struct MainSettingsView: View {
    @EnvironmentObject private var appDelegate: AppDelegate
    @AppStorage("appLanguage") private var appLanguage = "en"
    @AppStorage("enterToOpen") private var enterToOpen = true
    @AppStorage("deleteToTrash") private var deleteToTrash = true
    @AppStorage("shiftDeletePermanent") private var shiftDeletePermanent = true
    @AppStorage("cmdRRename") private var cmdRRename = true
    @AppStorage("cutAndPaste") private var cutAndPaste = true
    @AppStorage("altEnterProperties") private var altEnterProperties = true
    @AppStorage("altNavFolders") private var altNavFolders = true
    @AppStorage("f5Refresh") private var f5Refresh = true
    @AppStorage("backspaceUpFolder") private var backspaceUpFolder = false
    @AppStorage("ctrlShortcuts") private var ctrlShortcuts = true
    @AppStorage("launchAtLogin") private var launchAtLogin = true
    @State private var didCopyReport = false
    @State private var showResetConfirmation = false
    @State private var isApplyingLoginChange = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            issuesBanner
            TabView {
                ScrollView {
                    VStack(spacing: Design.groupSpacing) {
                        shortcutGuideGroup
                        fileManagementGroup
                        navigationGroup
                    }
                    .padding()
                }
                .tabItem {
                    Label(L10n.tr(appLanguage, "tab.shortcuts"), systemImage: "keyboard")
                }
                ScrollView {
                    VStack(spacing: Design.groupSpacing) {
                        systemGroup
                    }
                    .padding()
                }
                .tabItem {
                    Label(L10n.tr(appLanguage, "group.system"), systemImage: "gearshape")
                }
                ScrollView {
                    VStack(spacing: Design.groupSpacing) {
                        permissionsGroup
                        diagnosticsGroup
                    }
                    .padding()
                }
                .tabItem {
                    Label(L10n.tr(appLanguage, "tab.status"), systemImage: "waveform.path.ecg")
                }
            }
            Divider()
            footer
        }
        .frame(minWidth: 470, idealWidth: 490, maxWidth: 560,
               minHeight: 540, idealHeight: 620, maxHeight: 780)
        .navigationTitle(L10n.tr(appLanguage, "window.title"))
        .background(WindowIdentifierSetter(id: WinFinderWindowID.settings))
        .environment(\.layoutDirection, appLanguage == "fa" ? .rightToLeft : .leftToRight)
        .confirmationDialog(
            L10n.tr(appLanguage, "reset.confirm"),
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.tr(appLanguage, "reset.confirmAction"), role: .destructive) {
                resetShortcutsToDefaults()
            }
            Button(L10n.tr(appLanguage, "reset.cancel"), role: .cancel) {}
        }
    }

    /// Restores every shortcut toggle to its compiled-in default. System-level
    /// choices (launch at login) and the interface language are untouched.
    /// Writes go straight to the defaults database — @AppStorage observes the
    /// change and re-renders, and there is exactly one default table to keep
    /// in sync (ShortcutSettings.keysAndDefaults).
    private func resetShortcutsToDefaults() {
        for entry in ShortcutSettings.keysAndDefaults {
            UserDefaults.standard.set(entry.value, forKey: entry.key)
        }
    }

    // MARK: سربرگ

    private var header: some View {
        HStack {
            Image(systemName: "keyboard.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Brand.headerGradient)
                )
                .shadow(color: Brand.accent.opacity(0.35), radius: 4, y: 2)
            VStack(alignment: .leading, spacing: 2) {
                Text("WinFinder Pro")
                    .font(.title2)
                    .fontWeight(.bold)
                Text(L10n.tr(appLanguage, "header.subtitle"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(L10n.tr(appLanguage, "header.version")) \(appVersionText())")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            statusBadge
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
        .animation(.easeInOut(duration: 0.2), value: appDelegate.eventTapState)
        .animation(.easeInOut(duration: 0.2), value: appDelegate.isPaused)
    }

    @ViewBuilder
    private var statusBadge: some View {
        if appDelegate.isAccessGranted {
            let state = appDelegate.eventTapState
            HStack(spacing: 6) {
                Circle()
                    .fill(AppStatusPresentation.color(isPaused: appDelegate.isPaused, state: state))
                    .frame(width: 10, height: 10)
                Text(AppStatusPresentation.label(
                    isPaused: appDelegate.isPaused,
                    state: state,
                    language: appLanguage
                ))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(AppStatusPresentation.color(isPaused: appDelegate.isPaused, state: state))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(AppStatusPresentation.color(isPaused: appDelegate.isPaused, state: state).opacity(0.12))
            .cornerRadius(12)
        } else {
            Button(L10n.tr(appLanguage, "header.enableAccess")) {
                appDelegate.requestAccessManually()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(nsColor: .systemOrange))
        }
    }

    // MARK: بنر خطاها

    @ViewBuilder
    private var issuesBanner: some View {
        if !appDelegate.activeIssues.isEmpty {
            VStack(spacing: 6) {
                ForEach(appDelegate.activeIssues, id: \.self) { issue in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(Color(nsColor: .systemOrange))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(issue.displayText(appLanguage))
                                .font(.caption)
                                .foregroundColor(.primary)
                            if issue == .finderAutomationDenied {
                                Button(L10n.tr(appLanguage, "issue.openAutomation")) {
                                    SystemSettingsOpener.openAutomation()
                                }
                                .font(.caption)
                                .buttonStyle(.bordered)
                            }
                        }
                        Spacer()
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(Color(nsColor: .systemOrange).opacity(0.08))
            .transition(.opacity.combined(with: .move(edge: .top)))
            .animation(.easeOut(duration: 0.2), value: appDelegate.activeIssues)
        }
    }

    // MARK: گروه‌های تنظیمات

    private var fileManagementGroup: some View {
        GroupBox(label: Label(L10n.tr(appLanguage, "group.files"), systemImage: "doc.on.doc")) {
            VStack(spacing: Design.rowSpacing) {
                ToggleRowItem(
                    title: L10n.tr(appLanguage, "enter.title"),
                    subtitle: L10n.tr(appLanguage, "enter.subtitle"),
                    isOn: $enterToOpen
                )
                Divider()
                ToggleRowItem(
                    title: L10n.tr(appLanguage, "delete.title"),
                    subtitle: deleteSubtitle,
                    isOn: $deleteToTrash
                )
                .disabled(backspaceUpFolder)
                .animation(.easeInOut(duration: 0.2), value: backspaceUpFolder)
                Divider()
                ToggleRowItem(
                    title: L10n.tr(appLanguage, "shiftDelete.title"),
                    subtitle: L10n.tr(appLanguage, "shiftDelete.subtitle"),
                    isOn: $shiftDeletePermanent
                )
                Divider()
                ToggleRowItem(
                    title: L10n.tr(appLanguage, "rename.title"),
                    subtitle: L10n.tr(appLanguage, "rename.subtitle"),
                    isOn: $cmdRRename
                )
            }
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }

    /// The trash toggle is overridden by the Delete-to-parent-folder shortcut;
    /// say so instead of showing a switch that silently does nothing.
    private var deleteSubtitle: String {
        if backspaceUpFolder {
            return L10n.tr(appLanguage, "delete.inactiveHint")
        }
        return L10n.tr(appLanguage, "delete.subtitle")
    }

    private var navigationGroup: some View {
        GroupBox(label: Label(L10n.tr(appLanguage, "group.nav"), systemImage: "arrow.triangle.swap")) {
            VStack(spacing: Design.rowSpacing) {
                ToggleRowItem(
                    title: L10n.tr(appLanguage, "cut.title"),
                    subtitle: L10n.tr(appLanguage, "cut.subtitle"),
                    isOn: $cutAndPaste
                )
                Divider()
                ToggleRowItem(
                    title: L10n.tr(appLanguage, "properties.title"),
                    subtitle: L10n.tr(appLanguage, "properties.subtitle"),
                    isOn: $altEnterProperties
                )
                Divider()
                ToggleRowItem(
                    title: L10n.tr(appLanguage, "altNav.title"),
                    subtitle: L10n.tr(appLanguage, "altNav.subtitle"),
                    isOn: $altNavFolders
                )
                Divider()
                ToggleRowItem(
                    title: L10n.tr(appLanguage, "backspace.title"),
                    subtitle: L10n.tr(appLanguage, "backspace.subtitle"),
                    isOn: $backspaceUpFolder
                )
                Divider()
                ToggleRowItem(
                    title: L10n.tr(appLanguage, "f5.title"),
                    subtitle: L10n.tr(appLanguage, "f5.subtitle"),
                    isOn: $f5Refresh
                )
                Divider()
                ToggleRowItem(
                    title: L10n.tr(appLanguage, "ctrl.title"),
                    subtitle: L10n.tr(appLanguage, "ctrl.subtitle"),
                    isOn: $ctrlShortcuts
                )
            }
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }

    private var systemGroup: some View {
        GroupBox(label: Label(L10n.tr(appLanguage, "group.system"), systemImage: "gearshape")) {
            VStack(spacing: Design.rowSpacing) {
                ToggleRowItem(
                    title: L10n.tr(appLanguage, "login.title"),
                    subtitle: L10n.tr(appLanguage, "login.subtitle"),
                    isOn: Binding(
                        get: { launchAtLogin },
                        set: { newValue in
                            applyLaunchAtLogin(newValue)
                        }
                    )
                )
                .disabled(isApplyingLoginChange)
                if !appDelegate.isRunningFromPreferredLocation {
                    Label(L10n.tr(appLanguage, "login.notApplications"), systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundColor(Color(nsColor: .systemOrange))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Divider()
                HStack {
                    Text(L10n.tr(appLanguage, "language.title"))
                        .fontWeight(.medium)
                    Spacer()
                    Picker("", selection: $appLanguage) {
                        ForEach(L10n.supportedLanguages, id: \.code) { language in
                            Text(language.nativeName).tag(language.code)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 150)
                    .labelsHidden()
                    .accessibilityLabel(L10n.tr(appLanguage, "language.title"))
                }
                Divider()
                HStack(spacing: 10) {
                    Button(L10n.tr(appLanguage, "settings.export")) {
                        exportSettings()
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                    Button(L10n.tr(appLanguage, "settings.import")) {
                        importSettings()
                    }
                    .buttonStyle(.bordered)
                }
                Divider()
                Button(L10n.tr(appLanguage, "reset.button"), role: .destructive) {
                    showResetConfirmation = true
                }
                .frame(maxWidth: .infinity)
                .help(L10n.tr(appLanguage, "reset.confirm"))
            }
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }

    private var permissionsGroup: some View {
        GroupBox(label: Label(L10n.tr(appLanguage, "perm.title"), systemImage: "lock.shield")) {
            VStack(spacing: Design.rowSpacing) {
                HStack {
                    Button(L10n.tr(appLanguage, "perm.openAccessibility")) {
                        SystemSettingsOpener.openAccessibility()
                    }
                    .buttonStyle(.bordered)
                    .help(L10n.tr(appLanguage, "perm.openAccessibility"))
                    Spacer()
                    Button(L10n.tr(appLanguage, "perm.openAutomation")) {
                        SystemSettingsOpener.openAutomation()
                    }
                    .buttonStyle(.bordered)
                    .help(L10n.tr(appLanguage, "perm.openAutomation"))
                }
                Text(L10n.tr(appLanguage, "perm.hint"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }

    // MARK: عیب‌یابی

    private var diagnosticsGroup: some View {
        GroupBox(label: Label(L10n.tr(appLanguage, "diag.title"), systemImage: "stethoscope")) {
            VStack(spacing: 8) {
                diagnosticRow(
                    L10n.tr(appLanguage, "diag.accessibility"),
                    value: appDelegate.isAccessGranted
                        ? L10n.tr(appLanguage, "diag.granted")
                        : L10n.tr(appLanguage, "diag.missing"),
                    ok: appDelegate.isAccessGranted
                )
                diagnosticRow(
                    L10n.tr(appLanguage, "diag.eventtap"),
                    value: eventTapStateText,
                    ok: appDelegate.eventTapState == .running && !appDelegate.isPaused
                )
                diagnosticRow(
                    L10n.tr(appLanguage, "diag.automation"),
                    value: appDelegate.isFinderAutomationDenied
                        ? L10n.tr(appLanguage, "diag.denied")
                        : L10n.tr(appLanguage, "diag.pending"),
                    ok: !appDelegate.isFinderAutomationDenied
                )
                diagnosticRow(
                    L10n.tr(appLanguage, "diag.macversion"),
                    value: ProcessInfo.processInfo.operatingSystemVersionString,
                    ok: true,
                    neutral: true
                )
                diagnosticRow(
                    L10n.tr(appLanguage, "diag.appversion"),
                    value: appVersionText(),
                    ok: true,
                    neutral: true
                )
                HStack {
                    Spacer()
                    Button(didCopyReport ? L10n.tr(appLanguage, "diag.copied") : L10n.tr(appLanguage, "diag.copyreport")) {
                        copyDiagnosticsReport()
                        didCopyReport = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            didCopyReport = false
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(didCopyReport)
                }
            }
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }

    private var eventTapStateText: String {
        if appDelegate.isPaused { return L10n.tr(appLanguage, "header.paused") }
        switch appDelegate.eventTapState {
        case .running:
            return L10n.tr(appLanguage, "header.active")
        case .failed, .retrying:
            return L10n.tr(appLanguage, "diag.failed")
        default:
            return L10n.tr(appLanguage, "header.connecting")
        }
    }

    private func diagnosticRow(_ title: String, value: String, ok: Bool, neutral: Bool = false) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption)
            Spacer()
            if !neutral {
                Circle()
                    .fill(ok ? Color(nsColor: .systemGreen) : Color(nsColor: .systemOrange))
                    .frame(width: 7, height: 7)
            }
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(neutral ? .primary : (ok ? Color(nsColor: .systemGreen) : Color(nsColor: .systemOrange)))
        }
    }

    private func copyDiagnosticsReport() {
        let accessibility = appDelegate.isAccessGranted ? "granted" : "missing"
        let automation = appDelegate.isFinderAutomationDenied ? "denied" : "not determined"
        let issues = appDelegate.activeIssues.map { $0.logText }.joined(separator: "; ")
        let report = """
        WinFinder Pro \(appVersionText())
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        Accessibility: \(accessibility)
        Event tap: \(appDelegate.eventTapState.rawValue)\(appDelegate.isPaused ? " (paused)" : "")
        Finder automation: \(automation)
        Issues: \(issues.isEmpty ? "none" : issues)
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)
    }

    private var shortcutGuideGroup: some View {
        GroupBox(label: Label(L10n.tr(appLanguage, "group.guide"), systemImage: "list.bullet.rectangle")) {
            VStack(alignment: .leading, spacing: 8) {
                let rows = shortcutRows
                if rows.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "keyboard")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        Text(L10n.tr(appLanguage, "guide.empty"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                        ForEach(rows, id: \.keys) { row in
                            GridRow {
                                Text(row.keys)
                                    .font(.system(.caption, design: .monospaced))
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(Color.secondary.opacity(0.10)))
                                    .overlay(Capsule().strokeBorder(Color.secondary.opacity(0.22)))
                                    .shadow(color: .black.opacity(0.10), radius: 0.5, y: 1)
                                    .environment(\.layoutDirection, .leftToRight)
                                Text(row.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
                Text(L10n.tr(appLanguage, "guide.hint"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }

    private var shortcutRows: [(keys: String, description: String)] {
        activeShortcutRows(language: appLanguage)
    }

    // MARK: پابرگ

    private var footer: some View {
        HStack {
            Text(L10n.tr(appLanguage, "footer.note"))
                .font(.footnote)
                .foregroundColor(.secondary)
            Spacer()
            Button(L10n.tr(appLanguage, "footer.close")) {
                NSApp.keyWindow?.close()
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.cancelAction)
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
    }

    /// Applies a launch-at-login change off the main thread so the SMAppService
    /// XPC round-trip cannot stutter the UI. The toggle moves optimistically
    /// and reverts if the service rejects the change.
    private func applyLaunchAtLogin(_ enabled: Bool) {
        guard !isApplyingLoginChange else { return }
        isApplyingLoginChange = true
        let previousValue = launchAtLogin
        launchAtLogin = enabled
        DispatchQueue.global(qos: .userInitiated).async {
            var success = false
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                success = true
            } catch {
                NSLog("WinFinder: launch-at-login update failed; previous state restored: \(error)")
            }
            DispatchQueue.main.async {
                isApplyingLoginChange = false
                if success {
                    // Reflect the service's real state, including the approval-pending state.
                    launchAtLogin = LaunchAtLoginState.isRegistered
                } else {
                    launchAtLogin = previousValue
                }
            }
        }
    }

    // MARK: برون‌بری و درون‌ریزی تنظیمات

    /// Export format: `{"version": 1, "language": "fa", "settings": {...}}`.
    /// The version lets future releases migrate older payloads; the language
    /// is exported too so a shared file reproduces the whole setup. Legacy
    /// flat `{key: bool}` files from 2.5.x still import.
    private static let exportFormatVersion = 1

    private func exportSettings() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "WinFinderSettings.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        var settings: [String: Bool] = [:]
        for entry in ShortcutSettings.keysAndDefaults {
            settings[entry.key] = UserDefaults.standard.bool(forKey: entry.key)
        }
        var payload: [String: Any] = [
            "version": Self.exportFormatVersion,
            "settings": settings,
        ]
        if L10n.supportedLanguages.contains(where: { $0.code == appLanguage }) {
            payload["language"] = appLanguage
        }
        do {
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: url, options: .atomic)
        } catch {
            NSLog("WinFinder: settings export failed: \(error)")
        }
    }

    private func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            let object = try JSONSerialization.jsonObject(with: data)

            // Accept both the versioned payload and the legacy flat format.
            var settingsPayload: [String: Bool]
            var languagePayload: String?
            if let versioned = object as? [String: Any], versioned["settings"] is [String: Bool] {
                settingsPayload = versioned["settings"] as? [String: Bool] ?? [:]
                languagePayload = versioned["language"] as? String
            } else if let legacy = object as? [String: Bool] {
                settingsPayload = legacy
                languagePayload = nil
            } else {
                showImportFailure()
                return
            }

            let knownKeys = Set(ShortcutSettings.keysAndDefaults.map { $0.key })
            var applied = 0
            for (key, value) in settingsPayload where knownKeys.contains(key) {
                UserDefaults.standard.set(value, forKey: key)
                applied += 1
            }
            // Only a known language code is applied; an unknown one is ignored
            // rather than corrupting the language picker.
            if let languagePayload,
               L10n.supportedLanguages.contains(where: { $0.code == languagePayload }) {
                UserDefaults.standard.set(languagePayload, forKey: "appLanguage")
            }
            if applied == 0 { showImportFailure() }
        } catch {
            NSLog("WinFinder: settings import failed: \(error)")
            showImportFailure()
        }
    }

    private func showImportFailure() {
        let alert = NSAlert()
        alert.messageText = L10n.tr(appLanguage, "settings.importFailed")
        alert.alertStyle = .warning
        alert.runModal()
    }
}

// MARK: - ردیف کلید تغییر وضعیت
struct ToggleRowItem: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    @State private var isHovering = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.medium)
                Text(subtitle).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .tint(Color("AccentColor"))
                .accessibilityLabel(title)
                .accessibilityHint(subtitle)
                .help(subtitle)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isHovering && isEnabled ? Color.secondary.opacity(0.07) : Color.clear)
        )
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovering)
    }
}

// MARK: - پنجره درباره
struct AboutView: View {
    @AppStorage("appLanguage") private var appLanguage = "en"

    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
            VStack(spacing: 3) {
                Text("WinFinder Pro")
                    .font(.title2)
                    .fontWeight(.bold)
                Text(L10n.tr(appLanguage, "header.subtitle"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(L10n.tr(appLanguage, "header.version")) \(appVersionText())")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Divider()
            Text(L10n.tr(appLanguage, "about.license"))
                .font(.caption)
                .foregroundColor(.secondary)
            Button(L10n.tr(appLanguage, "about.github")) {
                if let url = URL(string: "https://github.com/hamidreza-tn/WinFinder") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
            .help(L10n.tr(appLanguage, "about.github"))
            Divider()
            Text(L10n.tr(appLanguage, "footer.note"))
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(width: 300)
        .navigationTitle(L10n.tr(appLanguage, "about.title"))
        .background(WindowIdentifierSetter(id: WinFinderWindowID.about))
        .environment(\.layoutDirection, appLanguage == "fa" ? .rightToLeft : .leftToRight)
    }
}
