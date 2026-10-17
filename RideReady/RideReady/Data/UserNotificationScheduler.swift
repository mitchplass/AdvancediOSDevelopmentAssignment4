import Foundation
import UserNotifications

/// Schedules RideReady's notifications with `UNUserNotificationCenter`.
final class UserNotificationScheduler: NotificationScheduling {
    static let breakReminderCategory = "rideReady.breakReminder"
    static let startBreakAction = "rideReady.startBreak"
    static let remindLaterAction = "rideReady.remindLater"

    private let center: UNUserNotificationCenter
    private let calendar: Calendar

    init(center: UNUserNotificationCenter = .current(), calendar: Calendar = .current) {
        self.center = center
        self.calendar = calendar
    }

    /// Break reminders offer Start break and Remind me in 30 min. Both run in
    /// the background, so the rider doesn't have to unlock the phone.
    static func registerCategories(on center: UNUserNotificationCenter) {
        center.setNotificationCategories([
            UNNotificationCategory(
                identifier: breakReminderCategory,
                actions: [
                    UNNotificationAction(identifier: startBreakAction, title: "Start break", options: []),
                    UNNotificationAction(identifier: remindLaterAction, title: "Remind me in 30 min", options: []),
                ],
                intentIdentifiers: []
            ),
        ])
    }

    func permission() async -> NotificationPermission {
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .allowed
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        @unknown default:
            return .denied
        }
    }

    func requestPermission() async throws -> NotificationPermission {
        _ = try await center.requestAuthorization(options: [.alert, .sound])
        return await permission()
    }

    func replacePendingNotifications(with notifications: [PlannedNotification]) async throws {
        let planned = Set(notifications.map(\.id))
        let stale = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { !planned.contains($0) }
        center.removePendingNotificationRequests(withIdentifiers: stale)
        for notification in notifications {
            try await center.add(request(for: notification))
        }
    }

    private func request(for notification: PlannedNotification) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = .default
        content.categoryIdentifier = notification.categoryIdentifier
        let fireAt = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: notification.fireDate
        )
        return UNNotificationRequest(
            identifier: notification.id,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: fireAt, repeats: false)
        )
    }
}
