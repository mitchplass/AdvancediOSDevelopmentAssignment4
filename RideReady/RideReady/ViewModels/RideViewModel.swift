import Combine
import Foundation
import os

/// Ride tab state: today's bike check, break reminder settings, and the ride
/// in progress (riding, on a break, or just finished).
@MainActor
final class RideViewModel: ObservableObject {
    enum Phase: Equatable {
        case ready
        case riding
        case onBreak
        case finished(RideSummary)
    }

    struct RideSummary: Equatable {
        let totalText: String
        let ridingText: String
        let breaksText: String
        let longestStintText: String
    }

    /// One finished ride in the recent rides list.
    struct RecentRide: Identifiable, Equatable {
        let id: UUID
        let dateText: String
        let detailText: String
    }

    /// Today's pre-ride check, shown above Start ride.
    struct BikeCheck: Equatable {
        enum Kind {
            case rideReady
            case needsAttention
            case notChecked
        }

        let kind: Kind
        let title: String
        let detail: String
    }

    struct RidingSnapshot {
        let ridingText: String
        /// Progress towards the next break; nil when reminders are off.
        let progress: Double?
        let dueTitle: String
        let dueDetail: String
    }

    struct BreakSnapshot {
        let restedText: String
        let progress: Double
        let title: String
        let detail: String
        let ridingSoFarText: String
    }

    @Published private(set) var phase: Phase = .ready
    @Published private(set) var bikeCheck = BikeCheck(kind: .notChecked, title: "", detail: "")
    @Published private(set) var settings: BreakReminderSettings
    @Published private(set) var permission: NotificationPermission = .notDetermined
    @Published private(set) var recentRides: [RecentRide] = []
    @Published var riderError: String?

    static let recentRideLimit = 5

    let intervalRange = BreakReminderSettings.intervalRange
    let intervalStep = BreakReminderSettings.intervalStep

    private let store: RideReadyStoring
    private let scheduler: NotificationScheduling
    private let startRideUseCase: StartRideUseCase
    private let takeBreakUseCase: TakeBreakUseCase
    private let resumeRideUseCase: ResumeRideUseCase
    private let endRideUseCase: EndRideUseCase
    private let saveSettings: SaveBreakReminderSettingsUseCase
    private let scheduleReminders: ScheduleBreakRemindersUseCase
    private var ride: Ride?

    private static let logger = Logger(subsystem: "com.iosdev.RideReady", category: "notifications")

    init(store: RideReadyStoring, scheduler: NotificationScheduling) {
        self.store = store
        self.scheduler = scheduler
        startRideUseCase = StartRideUseCase(store: store)
        takeBreakUseCase = TakeBreakUseCase(store: store)
        resumeRideUseCase = ResumeRideUseCase(store: store)
        endRideUseCase = EndRideUseCase(store: store)
        saveSettings = SaveBreakReminderSettingsUseCase(store: store)
        scheduleReminders = ScheduleBreakRemindersUseCase(store: store, scheduler: scheduler)
        settings = store.breakReminderSettings()
        reload()
    }

    var intervalText: String {
        DurationText.string(for: TimeInterval(settings.intervalMinutes * 60))
    }

    /// Reminders are on but iOS won't show them.
    var remindersBlocked: Bool {
        settings.isEnabled && permission == .denied
    }

    var startedText: String {
        ride.map { DayTimeText.time($0.startedAt) } ?? ""
    }

    var breaksText: String {
        "\(ride?.stops.count ?? 0)"
    }

    var reminderText: String {
        settings.isEnabled ? "every \(intervalText)" : "Off"
    }

    func reload() {
        bikeCheck = makeBikeCheck()
        settings = store.breakReminderSettings()
        recentRides = store.completedRides().prefix(Self.recentRideLimit).map(Self.recentRide(for:))
        ride = store.activeRide()
        if let ride {
            phase = ride.isOnBreak ? .onBreak : .riding
        } else if case .finished = phase {
            return
        } else {
            phase = .ready
        }
    }

    func setRemindersEnabled(_ isEnabled: Bool) {
        var updated = settings
        updated.isEnabled = isEnabled
        save(updated)
    }

    func setIntervalMinutes(_ minutes: Int) {
        var updated = settings
        updated.intervalMinutes = minutes
        save(updated)
    }

    /// Asks for notification permission the first time reminders are needed,
    /// then starts the ride and schedules its reminders.
    func startRide() async {
        riderError = nil
        if settings.isEnabled, await scheduler.permission() == .notDetermined {
            do {
                _ = try await scheduler.requestPermission()
            } catch {
                Self.logger.error("Notification permission request failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        perform { _ = try startRideUseCase.start() }
        await refreshReminders()
    }

    func takeBreak() async {
        perform { _ = try takeBreakUseCase.takeBreak() }
        await refreshReminders()
    }

    func backOnTheRoad() async {
        perform { _ = try resumeRideUseCase.resume() }
        await refreshReminders()
    }

    func endRide() async {
        do {
            let ended = try endRideUseCase.end()
            ride = nil
            phase = .finished(Self.summary(for: ended))
            riderError = nil
            reload()
        } catch {
            riderError = error.localizedDescription
        }
        await refreshReminders()
    }

    func dismissSummary() {
        phase = .ready
        reload()
    }

    func ridingSnapshot(at date: Date) -> RidingSnapshot {
        let ridden = ride?.ridingTimeSinceRest(at: date) ?? 0
        let ridingText = DurationText.string(for: ridden)
        guard settings.isEnabled else {
            return RidingSnapshot(
                ridingText: ridingText,
                progress: nil,
                dueTitle: "Break reminders are off",
                dueDetail: "Take regular breaks, even if you don't feel tired."
            )
        }

        let interval = TimeInterval(settings.intervalMinutes * 60)
        let remaining = interval - ridden
        let dueTitle: String
        let dueDetail: String
        if remaining >= 60 {
            dueTitle = "Break due in \(DurationText.string(for: remaining, roundingUp: true))"
            dueDetail = "around \(DayTimeText.time(date.addingTimeInterval(remaining)))"
        } else if remaining > -60 {
            dueTitle = "Break due now"
            dueDetail = "Pull over somewhere safe when you can."
        } else {
            dueTitle = "Break overdue by \(DurationText.string(for: -remaining))"
            dueDetail = "Pull over somewhere safe when you can."
        }

        if let remindAgainAt = ride?.remindAgainAt, remindAgainAt > date {
            return RidingSnapshot(
                ridingText: ridingText,
                progress: min(1, ridden / interval),
                dueTitle: dueTitle,
                dueDetail: "Next reminder at \(DayTimeText.time(remindAgainAt))"
            )
        }
        return RidingSnapshot(
            ridingText: ridingText,
            progress: min(1, ridden / interval),
            dueTitle: dueTitle,
            dueDetail: dueDetail
        )
    }

    func breakSnapshot(at date: Date) -> BreakSnapshot {
        let rested = ride?.currentStop?.duration(at: date) ?? 0
        let ridingSoFar = DurationText.string(for: ride?.totalRidingTime(at: date) ?? 0)
        if rested >= Ride.fullRest {
            return BreakSnapshot(
                restedText: DurationText.string(for: rested),
                progress: 1,
                title: "Fully rested",
                detail: "Your riding clock resets when you set off.",
                ridingSoFarText: ridingSoFar
            )
        }
        return BreakSnapshot(
            restedText: DurationText.string(for: rested),
            progress: rested / Ride.fullRest,
            title: "\(DurationText.string(for: Ride.fullRest - rested, roundingUp: true)) to a full rest",
            detail: "Breaks of 15 min or more reset your riding clock.",
            ridingSoFarText: ridingSoFar
        )
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
            riderError = nil
        } catch {
            riderError = error.localizedDescription
        }
        reload()
    }

    private func save(_ updated: BreakReminderSettings) {
        do {
            settings = try saveSettings.save(updated)
            riderError = nil
        } catch {
            riderError = error.localizedDescription
        }
    }

    /// Re-plans break reminders and reads whether iOS will show them. Runs on
    /// every ride action and when the app comes back, e.g. after the rider
    /// turns notifications on in Settings mid-ride.
    func refreshReminders() async {
        do {
            permission = try await scheduleReminders.refresh()
        } catch {
            Self.logger.error("Couldn't reschedule break reminders: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func makeBikeCheck() -> BikeCheck {
        if store.activeInspection() != nil {
            return BikeCheck(
                kind: .notChecked,
                title: "Pre-ride check in progress",
                detail: "Finish it on the Bike tab before you head off."
            )
        }
        guard let latest = store.completedInspections().first,
              let completedAt = latest.completedAt,
              Calendar.current.isDateInToday(completedAt) else {
            return BikeCheck(
                kind: .notChecked,
                title: "Bike not checked today",
                detail: "Do a pre-ride check before you head off."
            )
        }

        let time = DayTimeText.time(completedAt)
        if latest.readiness == .readyToRide {
            return BikeCheck(kind: .rideReady, title: "Bike checked today", detail: "\(time) · ride ready")
        }
        let flagged = latest.findings
            .filter { $0.result == .needsAttention }
            .map(\.item.title)
        return BikeCheck(
            kind: .needsAttention,
            title: "Bike not ride ready",
            detail: flagged.isEmpty
                ? "\(time) · something needs attention"
                : "\(time) · \(flagged.joined(separator: ", ")) flagged"
        )
    }

    private static func summary(for ride: Ride) -> RideSummary {
        let end = ride.endedAt ?? ride.startedAt
        return RideSummary(
            totalText: DurationText.string(for: end.timeIntervalSince(ride.startedAt)),
            ridingText: DurationText.string(for: ride.totalRidingTime(at: end)),
            breaksText: "\(ride.stops.count)",
            longestStintText: DurationText.string(for: ride.longestStint(at: end))
        )
    }

    private static func recentRide(for ride: Ride) -> RecentRide {
        let end = ride.endedAt ?? ride.startedAt
        let breaks: String
        switch ride.stops.count {
        case 0: breaks = "no breaks"
        case 1: breaks = "1 break"
        default: breaks = "\(ride.stops.count) breaks"
        }
        return RecentRide(
            id: ride.id,
            dateText: DayTimeText.string(for: ride.startedAt),
            detailText: "\(DurationText.string(for: end.timeIntervalSince(ride.startedAt))) · \(breaks)"
        )
    }
}
