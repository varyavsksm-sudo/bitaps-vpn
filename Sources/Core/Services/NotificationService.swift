import Foundation
import UserNotifications

// MARK: - Local notifications
//
// Drives the four notification toggles in Settings. The master "Уведомления"
// toggle requests system permission; the per-event toggles (drop / expiry /
// data) gate whether we actually post. Uses local notifications only — no
// server needed — so these work in this build.

public enum NotificationService {
    private static var center: UNUserNotificationCenter { .current() }

    /// Ask the OS for permission (shows the system prompt). Called when the user
    /// turns the master toggle on.
    public static func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// Post a notification after `delay` seconds (default: ~immediately).
    public static func post(title: String, body: String,
                            id: String = UUID().uuidString, delay: TimeInterval = 1) {
        center.getNotificationSettings { s in
            guard s.authorizationStatus == .authorized || s.authorizationStatus == .provisional else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false)
            center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
    }

    public static func cancel(_ id: String) {
        center.removePendingNotificationRequests(withIdentifiers: [id])
    }

    /// Schedule a reminder `daysBefore` the subscription expiry date.
    public static func scheduleExpiry(at expiry: Date, daysBefore: Int = 2) {
        cancel("bitaps.expiry")
        let fireDate = Calendar.current.date(byAdding: .day, value: -daysBefore, to: expiry) ?? expiry
        let delay = fireDate.timeIntervalSinceNow
        guard delay > 1 else { return }
        post(title: NSLocalizedString("Подписка истекает", comment: ""),
             body: NSLocalizedString("Напомним продлить — скоро закончится доступ.", comment: ""),
             id: "bitaps.expiry", delay: delay)
    }
}
