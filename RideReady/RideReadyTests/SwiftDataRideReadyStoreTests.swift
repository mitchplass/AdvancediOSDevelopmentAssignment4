import XCTest
@testable import RideReady

final class SwiftDataRideReadyStoreTests: XCTestCase {
    private var store: SwiftDataRideReadyStore!

    override func setUpWithError() throws {
        store = try SwiftDataRideReadyStore(inMemory: true)
    }

    override func tearDown() {
        store = nil
    }

    func test_saveMotorcycle_roundTripsProfileAndPhoto() {
        store.save(.yamahaMT07())
        store.saveMotorcyclePhoto(Data("photo".utf8))

        let motorcycle = store.motorcycle()
        XCTAssertEqual(motorcycle?.name, "Yamaha MT-07")
        XCTAssertEqual(motorcycle?.finalDrive, .chain)
        XCTAssertEqual(motorcycle?.frontTyrePressurePSI, 36)
        XCTAssertEqual(motorcycle?.chainSlackMaxMillimetres, 35)
        XCTAssertEqual(store.motorcyclePhoto(), Data("photo".utf8))
    }

    func test_activeInspection_predicate_ignoresCompletedWalkArounds() {
        let bike = Motorcycle.yamahaMT07()
        store.save(bike)
        store.save(makeInspection(bike: bike, completed: true, ready: true))
        let active = makeInspection(bike: bike, completed: false, ready: false)
        store.save(active)

        XCTAssertEqual(store.activeInspection()?.id, active.id)
        XCTAssertEqual(store.completedInspections().count, 1)
        XCTAssertEqual(store.completedInspections().first?.readiness, .readyToRide)
    }

    func test_completedRides_predicate_returnsNewestFirst_andKeepsStops() {
        let olderEnd = Date(timeIntervalSince1970: 1_700_000_000)
        let newerEnd = Date(timeIntervalSince1970: 1_800_000_000)
        let older = makeRide(endedAt: olderEnd)
        store.save(older)
        let newer = makeRide(endedAt: newerEnd)
        store.save(newer)
        store.save(Ride(
            id: UUID(),
            startedAt: Date(timeIntervalSince1970: 1_900_000_000),
            endedAt: nil,
            stops: [],
            remindAgainAt: nil
        ))

        let completed = store.completedRides()
        XCTAssertEqual(completed.map(\.id), [newer.id, older.id])
        XCTAssertEqual(completed.first?.stops.count, 1)
        XCTAssertNil(store.activeRide()?.endedAt)
        XCTAssertNotEqual(store.activeRide()?.id, newer.id)
    }

    func test_eraseAll_removesBikeChecksRidesAndSettings() {
        store.save(.yamahaMT07())
        store.save(SafetyStreak(consecutiveDays: 4, lastCompletedOn: Date()))
        store.save(BreakReminderSettings(isEnabled: false, intervalMinutes: 45))
        store.save(makeRide(endedAt: Date()))
        store.saveTracks([Track(name: "Phillip Island")])
        store.saveSessions([
            Session(vehicleID: UUID(), trackID: UUID(), laps: [Lap(lapNumber: 1, time: 90)])
        ])

        store.eraseAll()

        XCTAssertNil(store.motorcycle())
        XCTAssertNil(store.motorcyclePhoto())
        XCTAssertTrue(store.completedInspections().isEmpty)
        XCTAssertNil(store.activeRide())
        XCTAssertTrue(store.completedRides().isEmpty)
        XCTAssertEqual(store.streak().consecutiveDays, 0)
        XCTAssertEqual(store.breakReminderSettings(), .standard)
        XCTAssertTrue(store.tracks().isEmpty)
        XCTAssertTrue(store.sessions().isEmpty)
    }

    func test_migration_copiesLegacyMotorcycleInspectionAndRide() throws {
        let suiteName = "RideReadyTests.migrate.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let legacy = UserDefaultsRideReadyStore(defaults: defaults)
        let bike = Motorcycle(
            name: "Honda CB500F",
            finalDrive: .chain,
            frontTyrePressurePSI: 32,
            rearTyrePressurePSI: 36,
            chainSlackMinMillimetres: 20,
            chainSlackMaxMillimetres: 30
        )
        legacy.save(bike)
        legacy.saveMotorcyclePhoto(Data("legacy-photo".utf8))
        let inspection = makeInspection(bike: bike, completed: true, ready: false)
        legacy.save(inspection)
        legacy.save(SafetyStreak(consecutiveDays: 3, lastCompletedOn: Date(timeIntervalSince1970: 1_700_000_000)))
        let ride = makeRide(endedAt: Date(timeIntervalSince1970: 1_700_100_000))
        legacy.save(ride)
        let track = Track(name: "Eastern Creek", location: "Sydney", lengthMeters: 3930)
        legacy.saveTracks([track])
        legacy.saveSessions([
            Session(
                vehicleID: Vehicle.rideReadyMotorcycleID,
                trackID: track.id,
                weather: .wet,
                laps: [Lap(lapNumber: 1, time: 99.5)]
            )
        ])

        store.migrateFromUserDefaultsIfNeeded(defaults: defaults)

        XCTAssertEqual(store.motorcycle()?.name, "Honda CB500F")
        XCTAssertEqual(store.motorcyclePhoto(), Data("legacy-photo".utf8))
        XCTAssertEqual(store.completedInspections().first?.id, inspection.id)
        XCTAssertEqual(store.completedInspections().first?.findings.first?.result, .needsAttention)
        XCTAssertEqual(store.streak().consecutiveDays, 3)
        XCTAssertEqual(store.completedRides().first?.id, ride.id)
        XCTAssertEqual(store.tracks().map(\.name), ["Eastern Creek"])
        XCTAssertEqual(store.sessions().first?.laps.map(\.time), [99.5])
        XCTAssertEqual(store.sessions().first?.weather, .wet)
        XCTAssertTrue(defaults.bool(forKey: RideReadyStorageKey.didMigrateToSwiftData))

        store.migrateFromUserDefaultsIfNeeded(defaults: defaults)
        store.save(Motorcycle.yamahaMT07())
        store.migrateFromUserDefaultsIfNeeded(defaults: defaults)
        XCTAssertEqual(store.motorcycle()?.name, "Yamaha MT-07")
        defaults.removePersistentDomain(forName: suiteName)
    }

    func test_eraseRideData_suppressesTheSampleMotorcycle() throws {
        let suiteName = "RideReadyTests.erase.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let legacy = UserDefaultsRideReadyStore(defaults: defaults)
        legacy.save(.yamahaMT07())
        store.save(.yamahaMT07())

        EraseRideDataUseCase(
            store: store,
            journal: EmptyJournal(),
            preferences: defaults
        ).erase()

        XCTAssertNil(store.motorcycle())
        XCTAssertNil(legacy.motorcycle())
        XCTAssertTrue(defaults.bool(forKey: RideReadyStorageKey.suppressSampleMotorcycle))
        defaults.removePersistentDomain(forName: suiteName)
    }

    func test_widgetSnapshot_isRideReadyOnlyForTodaysPassingCheck() {
        let bike = Motorcycle.yamahaMT07()
        store.save(bike)
        var snapshot = RideReadyWidgetPublisher.snapshot(from: store)
        XCTAssertFalse(snapshot.isRideReady)

        let now = Date()
        store.save(makeInspection(bike: bike, completedAt: now, ready: true))
        snapshot = RideReadyWidgetPublisher.snapshot(from: store, now: now)
        XCTAssertTrue(snapshot.isRideReady)
        XCTAssertEqual(snapshot.bikeName, bike.name)
        XCTAssertEqual(snapshot.ridePhase, "Not riding")

        store.save(Ride(
            id: UUID(),
            startedAt: now,
            endedAt: nil,
            stops: [RideStop(startedAt: now, endedAt: nil)],
            remindAgainAt: nil
        ))
        snapshot = RideReadyWidgetPublisher.snapshot(from: store, now: now)
        XCTAssertEqual(snapshot.ridePhase, "On a break")
    }

    private func makeInspection(bike: Motorcycle, completed: Bool, ready: Bool) -> PreRideInspection {
        makeInspection(
            bike: bike,
            completedAt: completed ? Date(timeIntervalSince1970: 1_750_000_000) : nil,
            ready: ready
        )
    }

    private func makeInspection(bike: Motorcycle, completedAt: Date?, ready: Bool) -> PreRideInspection {
        let findings = bike.requiredInspectionItems().map { item in
            InspectionFinding(
                item: item,
                result: ready || item != .tyres ? .ok : .needsAttention
            )
        }
        return PreRideInspection(
            id: UUID(),
            motorcycle: bike,
            startedAt: Date(timeIntervalSince1970: 1_750_000_000),
            findings: findings,
            completedAt: completedAt,
            readiness: completedAt == nil ? nil : (ready ? .readyToRide : .notRideReady)
        )
    }

    private struct EmptyJournal: RideJournalRepository {
        func entries(forRide rideID: UUID) throws -> [JournalEntry] { [] }
        func save(_ entry: JournalEntry) throws {}
        func eraseAll() throws {}
    }

    private func makeRide(endedAt: Date) -> Ride {
        Ride(
            id: UUID(),
            startedAt: endedAt.addingTimeInterval(-3_600),
            endedAt: endedAt,
            stops: [RideStop(startedAt: endedAt.addingTimeInterval(-1_200), endedAt: endedAt.addingTimeInterval(-600))],
            remindAgainAt: nil
        )
    }
}
