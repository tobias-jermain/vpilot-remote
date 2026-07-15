import Foundation
import UserNotifications

protocol NotificationManaging {
    func requestAuthorization()
    func notify(title: String, body: String)
}

/// Thin wrapper around UNUserNotificationCenter. Kept behind a protocol so the
/// client layer doesn't need to be exercised against real notification
/// permissions in previews/tests.
final class NotificationManager: NotificationManaging {
    static let shared = NotificationManager()

    private init() {}

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func notify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
