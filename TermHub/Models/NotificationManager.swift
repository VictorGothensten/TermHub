import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    private var authorized = false

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            self?.authorized = granted
        }
    }

    func sendCompletionNotification(sessionTitle: String, lastLine: String, sessionId: UUID, workspaceId: UUID) {
        guard authorized else {
            requestPermission()
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Terminal ready"
        content.subtitle = sessionTitle
        content.body = lastLine.isEmpty ? "Command completed" : lastLine
        content.sound = .default
        content.userInfo = [
            "sessionId": sessionId.uuidString,
            "workspaceId": workspaceId.uuidString,
        ]

        let request = UNNotificationRequest(
            identifier: "idle-\(sessionId.uuidString)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
