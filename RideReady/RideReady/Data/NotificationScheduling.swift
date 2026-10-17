import Foundation

/// Whether the rider lets RideReady show notifications.
enum NotificationPermission: Equatable {
    case notDetermined
    case allowed
    case denied
}

/// A notification RideReady asks iOS to deliver at a set time.
struct PlannedNotification: Equatable {
    let id: String
    let fireDate: Date
    let title: String
    let body: String
    let categoryIdentifier: String
}

/// Hands RideReady's planned notifications to iOS.
///
/// Business Rule: after a replace, the pending notifications match the plan
/// exactly; anything no longer planned is withdrawn.
protocol NotificationScheduling {
    func permission() async -> NotificationPermission
    func requestPermission() async throws -> NotificationPermission
    func replacePendingNotifications(with notifications: [PlannedNotification]) async throws
}
