import XCTest
@testable import RideReady

final class BreakReminderTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var store: UserDefaultsRideReadyStore!
    private var scheduler: SpyNotificationScheduler!
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUpWithError() throws {
        suiteName = "RideReadyTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        store = UserDefaultsRideReadyStore(defaults: defaults)
        scheduler = SpyNotificationScheduler()
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        store = nil
        scheduler = nil
        suiteName = nil
    }

    func test_reminders_fireAtIntervalThenEveryThirtyMinutesThreeMoreTimes() async throws {
        _ = try StartRideUseCase(store: store, now: { self.start }).start()

        try await refresh(atMinute: 0)

        XCTAssertEqual(scheduler.pending.map(\.fireDate), [120, 150, 180, 210].map(minutes))
    }

    func test_noReminders_whileOnABreak() async throws {
        _ = try StartRideUseCase(store: store, now: { self.start }).start()
        _ = try TakeBreakUseCase(store: store, now: { self.minutes(60) }).takeBreak()

        try await refresh(atMinute: 61)

        XCTAssertTrue(scheduler.pending.isEmpty)
    }

    func test_shortStopAfterTheInterval_remindsStraightAway() async throws {
        _ = try StartRideUseCase(store: store, now: { self.start }).start()
        _ = try TakeBreakUseCase(store: store, now: { self.minutes(125) }).takeBreak()
        _ = try ResumeRideUseCase(store: store, now: { self.minutes(130) }).resume()

        try await refresh(atMinute: 130)

        XCTAssertEqual(scheduler.pending.first?.fireDate, minutes(130).addingTimeInterval(5))
    }

    func test_fullRest_restartsTheIntervalFromBackOnTheRoad() async throws {
        _ = try StartRideUseCase(store: store, now: { self.start }).start()
        _ = try TakeBreakUseCase(store: store, now: { self.minutes(90) }).takeBreak()
        _ = try ResumeRideUseCase(store: store, now: { self.minutes(110) }).resume()

        try await refresh(atMinute: 110)

        XCTAssertEqual(scheduler.pending.first?.fireDate, minutes(230))
    }

    func test_remindMeLater_holdsTheNextReminderForThirtyMinutes() async throws {
        _ = try StartRideUseCase(store: store, now: { self.start }).start()
        _ = try SnoozeBreakReminderUseCase(store: store, now: { self.minutes(120) }).snooze()

        try await refresh(atMinute: 120)

        XCTAssertEqual(scheduler.pending.first?.fireDate, minutes(150))
    }

    func test_noReminders_whenTurnedOffOrNotificationsDenied() async throws {
        _ = try StartRideUseCase(store: store, now: { self.start }).start()
        store.save(BreakReminderSettings(isEnabled: false, intervalMinutes: 120))
        try await refresh(atMinute: 0)
        XCTAssertTrue(scheduler.pending.isEmpty)

        store.save(BreakReminderSettings.standard)
        scheduler.permissionToReport = .denied
        let permission = try await refresh(atMinute: 0)

        XCTAssertEqual(permission, .denied)
        XCTAssertTrue(scheduler.pending.isEmpty)
    }

    func test_endingARideOnABreak_closesTheBreak() throws {
        _ = try StartRideUseCase(store: store, now: { self.start }).start()
        _ = try TakeBreakUseCase(store: store, now: { self.minutes(60) }).takeBreak()

        let ended = try EndRideUseCase(store: store, now: { self.minutes(70) }).end()

        XCTAssertEqual(ended.stops.last?.endedAt, minutes(70))
        XCTAssertEqual(ended.endedAt, minutes(70))
        XCTAssertNil(store.activeRide())
    }

    func test_rideActions_failInTheWrongState() throws {
        XCTAssertThrowsError(try TakeBreakUseCase(store: store).takeBreak()) { error in
            XCTAssertEqual(error as? RideError, .noRideInProgress)
        }
        _ = try StartRideUseCase(store: store).start()
        XCTAssertThrowsError(try StartRideUseCase(store: store).start()) { error in
            XCTAssertEqual(error as? RideError, .rideInProgress)
        }
        XCTAssertThrowsError(try ResumeRideUseCase(store: store).resume()) { error in
            XCTAssertEqual(error as? RideError, .notOnBreak)
        }
    }

    func test_saveSettings_acceptsThirtyMinutesToFourHoursInFifteenMinuteSteps() throws {
        let useCase = SaveBreakReminderSettingsUseCase(store: store)

        for minutes in [30, 240] {
            XCTAssertNoThrow(try useCase.save(BreakReminderSettings(isEnabled: true, intervalMinutes: minutes)))
        }
        for minutes in [15, 255, 100] {
            XCTAssertThrowsError(try useCase.save(BreakReminderSettings(isEnabled: true, intervalMinutes: minutes))) { error in
                XCTAssertEqual(error as? SaveBreakReminderSettingsError, .intervalOutOfRange)
            }
        }
    }

    @discardableResult
    private func refresh(atMinute minute: Double) async throws -> NotificationPermission {
        try await ScheduleBreakRemindersUseCase(
            store: store,
            scheduler: scheduler,
            now: { self.minutes(minute) }
        ).refresh()
    }

    private func minutes(_ value: Double) -> Date {
        start.addingTimeInterval(value * 60)
    }
}

private final class SpyNotificationScheduler: NotificationScheduling {
    var permissionToReport: NotificationPermission = .allowed
    private(set) var pending: [PlannedNotification] = []

    func permission() async -> NotificationPermission {
        permissionToReport
    }

    func requestPermission() async throws -> NotificationPermission {
        permissionToReport
    }

    func replacePendingNotifications(with notifications: [PlannedNotification]) async throws {
        pending = notifications
    }
}
