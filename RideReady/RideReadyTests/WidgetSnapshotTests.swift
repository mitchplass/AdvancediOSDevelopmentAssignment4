import XCTest
@testable import RideReady

final class WidgetSnapshotTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Australia/Sydney")!
        return value
    }

    private func date(_ day: Int, hour: Int = 10, month: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    func test_passedCheckExpiresAtLocalMidnight() {
        let snapshot = RideReadyWidgetSnapshot(
            motorcycleName: "Bike", lastCompletedAt: date(17), lastCheckPassed: true
        )
        XCTAssertEqual(snapshot.status(at: date(17, hour: 23), calendar: calendar), .checked)
        XCTAssertEqual(snapshot.status(at: date(18, hour: 0), calendar: calendar), .notChecked)
    }

    func test_futureCompletionDoesNotCountAsPassedToday() {
        let snapshot = RideReadyWidgetSnapshot(
            motorcycleName: "Bike", lastCompletedAt: date(17, hour: 15), lastCheckPassed: true
        )
        XCTAssertEqual(snapshot.status(at: date(17), calendar: calendar), .notChecked)
    }

    func test_unfinishedCheckOverridesEarlierPass() {
        let snapshot = RideReadyWidgetSnapshot(
            motorcycleName: "Bike", hasActiveInspection: true,
            lastCompletedAt: date(17), lastCheckPassed: true
        )
        XCTAssertEqual(snapshot.status(at: date(17), calendar: calendar), .inProgress)
    }

    func test_attentionDoesNotExpireAtMidnight() {
        let snapshot = RideReadyWidgetSnapshot(motorcycleName: "Bike", needsAttention: true)
        XCTAssertEqual(snapshot.status(at: date(18), calendar: calendar), .needsAttention)
    }

    func test_missingMotorcycleRequiresSetup() {
        XCTAssertEqual(
            RideReadyWidgetSnapshot(motorcycleName: nil).status(at: date(17)), .setup
        )
    }

    func test_expiryUsesCalendarDaysAcrossDaylightSaving() {
        let start = date(4, hour: 0)
        let end = RideReadyWidgetSnapshot.nextDay(after: start, calendar: calendar)
        XCTAssertEqual(end, date(5, hour: 0))
        XCTAssertEqual(end.timeIntervalSince(start), 23 * 60 * 60)
    }

    func test_deepLinkAcceptsOnlyKnownRoutes() {
        XCTAssertEqual(RideReadyWidgetConfiguration.destination(for: URL(string: "rideready://check")!), .check)
        XCTAssertEqual(RideReadyWidgetConfiguration.destination(for: URL(string: "rideready://home")!), .home)
        for invalid in ["https://check", "rideready://delete", "rideready://check/extra", "rideready://check?complete=true"] {
            XCTAssertNil(RideReadyWidgetConfiguration.destination(for: URL(string: invalid)!))
        }
    }

    func test_snapshotRoundTripAndCorruptDataFallback() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("snapshot.json")
        let file = WidgetSnapshotFile(fileURL: url)
        XCTAssertNil(file.read())
        XCTAssertTrue(try file.write(.sample))
        XCTAssertEqual(file.read(), .sample)
        XCTAssertFalse(try file.write(.sample))
        try Data("broken".utf8).write(to: url)
        XCTAssertNil(file.read())
        var incompatible = RideReadyWidgetSnapshot.sample
        incompatible.version = 3
        try file.write(incompatible)
        XCTAssertNil(file.read())
    }

    func test_missingAppGroupFailsWithoutCrashing() {
        let file = WidgetSnapshotFile(fileURL: nil)
        XCTAssertNil(file.read())
        XCTAssertThrowsError(try file.write(.sample))
    }

    func test_lastCheckLabelUsesTimelineDateAtMidnight() {
        let locale = Locale(identifier: "en_AU")
        let completed = date(17, hour: 23)
        let today = WidgetLastCheckText.string(for: completed, relativeTo: date(17, hour: 23), calendar: calendar, locale: locale)
        let tomorrow = WidgetLastCheckText.string(for: completed, relativeTo: date(18, hour: 0), calendar: calendar, locale: locale)
        XCTAssertTrue(today.hasPrefix("Today,"))
        XCTAssertTrue(tomorrow.hasPrefix("Yesterday,"))
        XCTAssertTrue(today.contains("11:"), "The label includes the completion time")
        let older = WidgetLastCheckText.string(for: completed, relativeTo: date(20), calendar: calendar, locale: locale)
        XCTAssertTrue(older.contains("2026"))
        XCTAssertFalse(older.contains("Yesterday"))
    }

    func test_missingLastCheckHasExplicitEmptyState() {
        XCTAssertEqual(WidgetLastCheckText.string(for: nil, relativeTo: date(17)), "No check for this setup")
    }
}

final class BuildWidgetSnapshotUseCaseTests: XCTestCase {
    func test_emptyRepositoryProducesSetupState() {
        let snapshot = BuildWidgetSnapshotUseCase(store: WidgetTestStore()).execute()
        XCTAssertEqual(snapshot.status(at: .now), .setup)
    }

    func test_completedIssueAndNewCheckReplaceEarlierPass() {
        let base = WidgetTestStore()
        var snapshots: [RideReadyWidgetSnapshot] = []
        let store = WidgetPublishingRideReadyStore(base: base) { snapshots.append($0) }
        store.save(Motorcycle.yamahaMT07())
        var completed = inspection(findings: Motorcycle.yamahaMT07().requiredInspectionItems().map {
            InspectionFinding(item: $0, result: .ok)
        })
        completed.completedAt = Date().addingTimeInterval(-60)
        completed.readiness = .readyToRide
        store.save(completed)
        XCTAssertEqual(snapshots.last?.status(at: .now), .checked)
        store.save(inspection(findings: []))
        XCTAssertEqual(snapshots.last?.status(at: .now), .inProgress)
        completed.readiness = .notRideReady
        completed.findings = [InspectionFinding(item: .tyres, result: .needsAttention)]
        store.save(completed)
        XCTAssertEqual(snapshots.last?.status(at: .now), .needsAttention)
    }

    func test_countsUniqueRequiredItemsAndShowsActiveIssue() {
        let store = WidgetTestStore()
        store.bike = .yamahaMT07()
        store.active = inspection(findings: [
            InspectionFinding(item: .tyres, result: .ok),
            InspectionFinding(item: .tyres, result: .ok),
            InspectionFinding(item: .chain, result: .needsAttention)
        ])
        let snapshot = BuildWidgetSnapshotUseCase(store: store).execute()
        XCTAssertEqual(snapshot.checkedItems, 2)
        XCTAssertEqual(snapshot.requiredItems, 4)
        XCTAssertEqual(snapshot.status(at: .now), .needsAttention)
        XCTAssertEqual(snapshot.flaggedItems, ["Chain"])
    }

    func test_newCheckRetainsPreviousCompletionTimeButNotOldIssues() {
        let store = WidgetTestStore()
        store.bike = .yamahaMT07()
        var previous = inspection(findings: [InspectionFinding(item: .tyres, result: .needsAttention)])
        previous.completedAt = Date(timeIntervalSince1970: 1_800_000_000)
        previous.readiness = .notRideReady
        store.completed = previous
        store.active = inspection(findings: [])
        let snapshot = BuildWidgetSnapshotUseCase(store: store).execute()
        XCTAssertEqual(snapshot.lastCompletedAt, previous.completedAt)
        XCTAssertEqual(snapshot.status(at: .now), .inProgress)
        XCTAssertTrue(snapshot.flaggedItems.isEmpty)
        XCTAssertFalse(snapshot.lastCheckPassed)
    }

    func test_completedIssueNamesAreIncludedOnceInChecklistOrder() {
        let store = WidgetTestStore()
        store.bike = .yamahaMT07()
        var previous = inspection(findings: [
            InspectionFinding(item: .chain, result: .needsAttention),
            InspectionFinding(item: .tyres, result: .needsAttention),
            InspectionFinding(item: .tyres, result: .needsAttention)
        ])
        previous.completedAt = .now
        previous.readiness = .notRideReady
        store.completed = previous
        let snapshot = BuildWidgetSnapshotUseCase(store: store).execute()
        XCTAssertEqual(snapshot.flaggedItems, ["Tyres", "Chain"])
        XCTAssertEqual(snapshot.lastCompletedAt, previous.completedAt)
    }

    func test_malformedPassedInspectionIsNotReportedAsPassed() {
        let store = WidgetTestStore()
        store.bike = .yamahaMT07()
        var completed = inspection(findings: [])
        completed.completedAt = .now
        completed.readiness = .readyToRide
        store.completed = completed
        XCTAssertFalse(BuildWidgetSnapshotUseCase(store: store).execute().lastCheckPassed)
    }

    func test_completedPassIsInvalidatedAfterBikeProfileChanges() {
        let store = WidgetTestStore()
        store.bike = .yamahaMT07()
        var completed = inspection(findings: Motorcycle.yamahaMT07().requiredInspectionItems().map {
            InspectionFinding(item: $0, result: .ok)
        })
        completed.completedAt = .now
        completed.readiness = .readyToRide
        store.completed = completed
        XCTAssertTrue(BuildWidgetSnapshotUseCase(store: store).execute().lastCheckPassed)
        store.bike?.frontTyrePressurePSI = 35
        let updated = BuildWidgetSnapshotUseCase(store: store).execute()
        XCTAssertFalse(updated.lastCheckPassed)
        XCTAssertNil(updated.lastCompletedAt)
    }

    func test_decoratorPublishesAfterSavingAndRetainsRepositoryData() {
        let base = WidgetTestStore()
        var snapshots: [RideReadyWidgetSnapshot] = []
        let store = WidgetPublishingRideReadyStore(base: base) { snapshots.append($0) }
        store.save(Motorcycle.yamahaMT07())
        XCTAssertEqual(snapshots.last?.motorcycleName, "Yamaha MT-07")
        store.save(inspection(findings: []))
        XCTAssertEqual(snapshots.last?.hasActiveInspection, true)
        XCTAssertEqual(store.activeInspection()?.id, base.active?.id)
        store.save(SafetyStreak(consecutiveDays: 2, lastCompletedOn: .now))
        store.saveMotorcyclePhoto(Data([1, 2, 3]))
        XCTAssertEqual(store.streak().consecutiveDays, 2)
        XCTAssertEqual(store.motorcyclePhoto(), Data([1, 2, 3]))
        XCTAssertEqual(snapshots.count, 2, "Non-widget fields must not request reloads")
    }

    func test_rideAndReminderOperationsStillReachUnderlyingRepository() {
        let base = WidgetTestStore()
        var publishCount = 0
        let store = WidgetPublishingRideReadyStore(base: base) { _ in publishCount += 1 }
        var ride = Ride(id: UUID(), startedAt: .now, endedAt: nil, stops: [], remindAgainAt: nil)
        store.save(ride)
        XCTAssertEqual(store.activeRide(), ride)
        let settings = BreakReminderSettings(isEnabled: false, intervalMinutes: 60)
        store.save(settings)
        XCTAssertEqual(store.breakReminderSettings(), settings)
        ride.endedAt = .now
        store.save(ride)
        XCTAssertNil(store.activeRide())
        XCTAssertEqual(store.completedRides(), [ride])
        XCTAssertEqual(publishCount, 0)
    }

    private func inspection(findings: [InspectionFinding]) -> PreRideInspection {
        PreRideInspection(id: UUID(), motorcycle: .yamahaMT07(), startedAt: .now,
                          findings: findings, completedAt: nil, readiness: nil)
    }
}

final class WidgetTestStore: RideReadyStoring {
    var bike: Motorcycle?
    var active: PreRideInspection?
    var completed: PreRideInspection?
    var photo: Data?
    var safetyStreak = SafetyStreak(consecutiveDays: 0, lastCompletedOn: nil)
    func motorcycle() -> Motorcycle? { bike }
    func save(_ motorcycle: Motorcycle) { bike = motorcycle }
    func motorcyclePhoto() -> Data? { photo }
    func saveMotorcyclePhoto(_ data: Data?) { photo = data }
    func activeInspection() -> PreRideInspection? { active }
    func save(_ inspection: PreRideInspection) {
        if inspection.completedAt == nil { active = inspection }
        else { completed = inspection; active = nil }
    }
    func completedInspections() -> [PreRideInspection] { completed.map { [$0] } ?? [] }
    func streak() -> SafetyStreak { safetyStreak }
    func save(_ streak: SafetyStreak) { safetyStreak = streak }
    var ride: Ride?
    var finishedRides: [Ride] = []
    var settings: BreakReminderSettings = .standard
    func activeRide() -> Ride? { ride }
    func completedRides() -> [Ride] { finishedRides }
    func save(_ ride: Ride) {
        if ride.endedAt == nil { self.ride = ride }
        else { finishedRides.append(ride); self.ride = nil }
    }
    func breakReminderSettings() -> BreakReminderSettings { settings }
    func save(_ settings: BreakReminderSettings) { self.settings = settings }
    var savedTracks: [Track] = []
    var savedSessions: [Session] = []
    func tracks() -> [Track] { savedTracks }
    func saveTracks(_ tracks: [Track]) { savedTracks = tracks }
    func sessions() -> [Session] { savedSessions }
    func saveSessions(_ sessions: [Session]) { savedSessions = sessions }
    func eraseAll() {
        bike = nil
        active = nil
        completed = nil
        photo = nil
        safetyStreak = SafetyStreak(consecutiveDays: 0, lastCompletedOn: nil)
        ride = nil
        finishedRides = []
        settings = .standard
        savedTracks = []
        savedSessions = []
    }
}
