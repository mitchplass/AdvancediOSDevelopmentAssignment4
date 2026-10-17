import Foundation

/// Keeps iOS's pending break reminders in step with the ride in progress.
/// Safe to run any time; it replaces the whole pending set.
///
/// Business Rules:
/// - While riding, the first reminder fires when riding time since the last
///   full rest reaches the rider's interval. If that time has already passed
///   (after a short stop), it fires straight away.
/// - "Remind me in 30 min" holds the next reminder until then.
/// - An ignored reminder repeats every 30 minutes, 3 more times.
/// - Nothing is pending while on a break, with no ride in progress, with
///   reminders off, or when notifications aren't allowed.
struct ScheduleBreakRemindersUseCase {
    static let repeatInterval: TimeInterval = 30 * 60
    static let repeatCount = 3

    let store: RideReadyStoring
    let scheduler: NotificationScheduling
    let now: () -> Date

    init(store: RideReadyStoring, scheduler: NotificationScheduling, now: @escaping () -> Date = Date.init) {
        self.store = store
        self.scheduler = scheduler
        self.now = now
    }

    /// Replaces the pending reminders with the current plan and reports
    /// whether iOS will deliver them.
    @discardableResult
    func refresh() async throws -> NotificationPermission {
        let permission = await scheduler.permission()
        let reminders = permission == .allowed ? plannedReminders() : []
        try await scheduler.replacePendingNotifications(with: reminders)
        return permission
    }

    private func plannedReminders() -> [PlannedNotification] {
        let settings = store.breakReminderSettings()
        guard settings.isEnabled, let ride = store.activeRide(), !ride.isOnBreak else {
            return []
        }

        let now = now()
        let ridden = ride.ridingTimeSinceRest(at: now)
        let due = now.addingTimeInterval(TimeInterval(settings.intervalMinutes * 60) - ridden)
        let first = max(due, ride.remindAgainAt ?? due, now.addingTimeInterval(5))

        return (0...Self.repeatCount).map { index in
            let fireDate = first.addingTimeInterval(TimeInterval(index) * Self.repeatInterval)
            let ridingAtFire = ridden + fireDate.timeIntervalSince(now)
            return PlannedNotification(
                id: "\(UserNotificationScheduler.breakReminderCategory).\(ride.id.uuidString).\(index)",
                fireDate: fireDate,
                title: "Time for a break",
                body: "You've been riding for \(DurationText.string(for: ridingAtFire)). Pull over somewhere safe, stretch and have a drink.",
                categoryIdentifier: UserNotificationScheduler.breakReminderCategory
            )
        }
    }
}
