import SwiftUI

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
            Button(L10n.tr(appLanguage, "menu.settings")) {
                appDelegate.showSettingsWindow()
            }
            Divider()
            Button(L10n.tr(appLanguage, "menu.quit")) {
                NSApplication.shared.terminate(nil)
            }
        }
        .environment(\.layoutDirection, appLanguage == "fa" ? .rightToLeft : .leftToRight)
    }

    private var statusRow: some View {
        HStack {
            Text(statusText)
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(statusText)
    }

    private var isRunning: Bool {
        appDelegate.isAccessGranted
            && appDelegate.eventTapState == .running
            && !appDelegate.isPaused
    }

    private var statusText: String {
        if appDelegate.isPaused { return L10n.tr(appLanguage, "menu.status.paused") }
        if isRunning { return L10n.tr(appLanguage, "menu.status.running") }
        if appDelegate.eventTapState == .failed || appDelegate.eventTapState == .retrying {
            return L10n.tr(appLanguage, "menu.status.error")
        }
        return L10n.tr(appLanguage, "menu.status.needsAccess")
    }

    private var statusColor: Color {
        if appDelegate.isPaused { return .gray }
        if isRunning { return .green }
        if appDelegate.eventTapState == .failed || appDelegate.eventTapState == .retrying {
            return .red
        }
        return .orange
    }
}
