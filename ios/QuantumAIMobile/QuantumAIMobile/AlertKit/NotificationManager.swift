import Foundation
import UserNotifications

public final class NotificationManager {
    public static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }

    public static func notifyPendingOutbox(count: Int) {
        let content = UNMutableNotificationContent()
        content.title = "İşlem Beklemede"
        content.body = "Ağ bağlantısı sağlandı. Gönderilmeyi bekleyen \(count) işleminiz var."
        content.sound = .default
        let request = UNNotificationRequest(identifier: "outbox_alert", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
