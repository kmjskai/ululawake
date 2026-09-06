import SwiftUI

@main
struct UlulaWakeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarPanel()
        } label: {
            MenuBarIcon()
        }
        .menuBarExtraStyle(.window)
    }
}

/// 菜单栏图标：开=睁眼站立 / 关=闭眼收拢 / 未授权=三角警示
struct MenuBarIcon: View {
    @ObservedObject private var controller = AppController.shared

    var body: some View {
        Group {
            if controller.authReady {
                Image(controller.isKeeping ? "MenuBarOwlAwake" : "MenuBarOwlSleeping")
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
            }
        }
        .foregroundStyle(color)
    }

    private var color: Color {
        if !controller.authReady { return .orange }
        return controller.isKeeping ? .yellow : .secondary
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        // Hosted unit tests must not request permissions or change system sleep.
        guard ProcessInfo.processInfo.environment["ULULAWAKE_UNIT_TESTS"] != "1" else { return }
        #endif
        NotificationService.shared.ensureAuthorized()
        AppController.shared.start()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        #if DEBUG
        if ProcessInfo.processInfo.environment["ULULAWAKE_UNIT_TESTS"] == "1" { return .terminateNow }
        #endif
        guard AppController.shared.prepareForTermination() else {
            sender.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = "无法安全退出 UlulaWake"
            alert.informativeText = "系统仍可能处于保持唤醒状态。请返回菜单栏面板重试；必要时在终端运行：sudo pmset -a disablesleep 0"
            alert.addButton(withTitle: "返回 App")
            alert.runModal()
            return .terminateCancel
        }
        return .terminateNow
    }
}
