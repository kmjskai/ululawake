import Foundation
import UserNotifications

/// 本地通知：恢复睡眠通知（带"重新保持"按钮）、电量告警
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        let category = UNNotificationCategory(
            identifier: "RESTORED",
            actions: [
                UNNotificationAction(identifier: "RESUME",
                                     title: NSLocalizedString("重新保持", comment: ""),
                                     options: [])
            ],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func ensureAuthorized() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func notifyRestored(reason: String) {
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("UlulaWake · 已恢复睡眠", comment: "")
        content.body = reason
        content.categoryIdentifier = "RESTORED"
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // 点击"重新保持"按钮
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        if response.actionIdentifier == "RESUME" {
            await MainActor.run { AppController.shared.resumeKeep() }
        }
    }
}
