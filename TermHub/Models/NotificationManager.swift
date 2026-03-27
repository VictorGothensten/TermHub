import Foundation
import AppKit

class NotificationManager {
    static let shared = NotificationManager()

    func requestPermission() {
        // No permission needed — we use dock bounce + in-app indicators
    }

    func sendCompletionNotification(sessionTitle: String, lastLine: String, sessionId: UUID, workspaceId: UUID) {
        DispatchQueue.main.async {
            // Bounce the dock icon to get attention
            NSApp.requestUserAttention(.informationalRequest)

            // Play a subtle sound
            NSSound(named: .init("Tink"))?.play()
        }
    }
}
