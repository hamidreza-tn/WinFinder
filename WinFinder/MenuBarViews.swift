import SwiftUI

// MARK: - زبان بصری مشترک وضعیت برنامه
/// One source of truth for the status label and color, shared by the menu
/// bar and the Settings header so the two never disagree.
enum AppStatusPresentation {
    static func label(isPaused: Bool, state: AppDelegate.EventTapState, language: String) -> String {
        if isPaused { return L10n.tr(language, "header.paused") }
        if state == .running { return L10n.tr(language, "header.active") }
        return L10n.tr(language, "header.connecting")
    }

    static func color(isPaused: Bool, state: AppDelegate.EventTapState) -> Color {
        // Semantic system colors: they follow the user's contrast and tint
        // preferences instead of fixed RGB values.
        if isPaused { return Color(nsColor: .systemGray) }
        if state == .running { return Color(nsColor: .systemGreen) }
        if state == .failed || state == .retrying { return Color(nsColor: .systemRed) }
        return Color(nsColor: .systemOrange)
    }
}

// MARK: - فهرست زنده میانبرهای فعال (نسخه فشرده برای منوبار)
struct MenuBarShortcutsSection: View {
    @AppStorage("appLanguage") private var appLanguage = "en"

    var body: some View {
        let rows = activeShortcutRows(language: appLanguage)
        if rows.isEmpty {
            Text(L10n.tr(appLanguage, "guide.empty"))
                .font(.caption2)
                .foregroundColor(.secondary)
        } else {
            ForEach(rows, id: \.keys) { row in
                HStack {
                    Text(row.keys)
                        .font(.system(size: 11, design: .monospaced))
                        .environment(\.layoutDirection, .leftToRight)
                    Spacer()
                    Text(row.description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - آیکون منوبار بر اساس وضعیت برنامه
struct MenuBarIconView: View {
    @ObservedObject var appDelegate: AppDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(systemName: symbolName)
            .accessibilityLabel("WinFinder Pro")
            .onAppear {
                // The status item is alive from launch, so it is the place to
                // capture the open-window action for AppKit-side use.
                appDelegate.registerOpenWindowAction(openWindow)
            }
    }

    private var symbolName: String {
        if appDelegate.isPaused {
            return "pause.circle.fill"
        }
        if !appDelegate.isAccessGranted {
            return "exclamationmark.triangle.fill"
        }
        switch appDelegate.eventTapState {
        case .running:
            return "keyboard.fill"
        case .failed, .retrying:
            return "exclamationmark.triangle.fill"
        default:
            return "keyboard"
        }
    }
}

// MARK: - منوی بالای صفحه
struct MenuBarStatusView: View {
    @EnvironmentObject private var appDelegate: AppDelegate
    @AppStorage("appLanguage") private var appLanguage = "en"

    var body: some View {
        Group {
            statusRow
            Divider()
            Toggle(L10n.tr(appLanguage, "menu.shortcutsEnabled"), isOn: Binding(
                get: { !appDelegate.isPaused },
                set: { appDelegate.setPaused(!$0) }
            ))
            if !appDelegate.isPaused {
                Button {
                    appDelegate.pauseForOneHour()
                } label: {
                    Label(L10n.tr(appLanguage, "menu.pauseForHour"), systemImage: "clock.badge.pause")
                }
            }
            Divider()
            MenuBarShortcutsSection()
            Divider()
            Button {
                appDelegate.showAboutWindow()
            } label: {
                Label(L10n.tr(appLanguage, "about.title"), systemImage: "info.circle")
            }
            Button {
                appDelegate.showSettingsWindow()
            } label: {
                Label(L10n.tr(appLanguage, "menu.settings"), systemImage: "gearshape")
            }
            Divider()
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label(L10n.tr(appLanguage, "menu.quit"), systemImage: "power")
            }
        }
        .environment(\.layoutDirection, appLanguage == "fa" ? .rightToLeft : .leftToRight)
    }

    private var statusRow: some View {
        let state = appDelegate.eventTapState
        return HStack {
            Text(AppStatusPresentation.label(
                isPaused: appDelegate.isPaused,
                state: state,
                language: appLanguage
            ))
            Circle()
                .fill(AppStatusPresentation.color(isPaused: appDelegate.isPaused, state: state))
                .frame(width: 8, height: 8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(AppStatusPresentation.label(
            isPaused: appDelegate.isPaused,
            state: state,
            language: appLanguage
        ))
    }
}
