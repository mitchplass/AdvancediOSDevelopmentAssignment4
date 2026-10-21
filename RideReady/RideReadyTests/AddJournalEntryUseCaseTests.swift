import XCTest
@testable import RideReady

final class AddJournalEntryUseCaseTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var store: UserDefaultsRideReadyStore!
    private var journal: MockRideJournalRepository!
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUpWithError() throws {
        suiteName = "RideReadyTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        store = UserDefaultsRideReadyStore(defaults: defaults)
        journal = MockRideJournalRepository()
        store.logPreRideCheck(.readyToRide, at: start)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        store = nil
        journal = nil
        suiteName = nil
    }

    func test_add_duringARide_savesATrimmedEntryForThatRide() throws {
        let ride = try StartRideUseCase(store: store, now: { self.start }).start()
        let photo = Data([0xFF, 0xD8])

        let entry = try makeUseCase().add(title: "  Lookout  ", note: " Great view \n", photo: photo)

        XCTAssertEqual(entry.rideID, ride.id)
        XCTAssertEqual(entry.title, "Lookout")
        XCTAssertEqual(entry.note, "Great view")
        XCTAssertEqual(entry.photo, photo)
        XCTAssertEqual(journal.saved, [entry])
    }

    func test_add_withoutARide_throwsNoRideInProgress() {
        XCTAssertThrowsError(try makeUseCase().add(title: "Lookout", note: "", photo: nil)) { error in
            XCTAssertEqual(error as? JournalError, .noRideInProgress)
        }
        XCTAssertTrue(journal.saved.isEmpty)
    }

    func test_add_rejectsBlankOrOverlongText() throws {
        _ = try StartRideUseCase(store: store, now: { self.start }).start()
        let tooLong = String(repeating: "a", count: JournalEntry.titleLimit + 1)

        XCTAssertThrowsError(try makeUseCase().add(title: "   ", note: "", photo: nil)) { error in
            XCTAssertEqual(error as? JournalError, .titleMissing)
        }
        XCTAssertThrowsError(try makeUseCase().add(title: tooLong, note: "", photo: nil)) { error in
            XCTAssertEqual(error as? JournalError, .tooLong)
        }
        XCTAssertTrue(journal.saved.isEmpty)
    }

    func test_add_whenStorageFails_mapsToCouldNotSave() throws {
        _ = try StartRideUseCase(store: store, now: { self.start }).start()
        journal.fails = true

        XCTAssertThrowsError(try makeUseCase().add(title: "Lookout", note: "", photo: nil)) { error in
            XCTAssertEqual(error as? JournalError, .couldNotSave)
        }
        XCTAssertThrowsError(try LoadRideJournalUseCase(journal: journal).entries(forRide: UUID())) { error in
            XCTAssertEqual(error as? JournalError, .couldNotLoad)
        }
    }

    func test_swiftDataRepository_returnsEachRidesEntriesInOrder() throws {
        let repository = try SwiftDataRideJournalRepository(inMemory: true)
        let rideID = UUID()
        let later = JournalEntry(id: UUID(), rideID: rideID, title: "Café", note: "", loggedAt: start.addingTimeInterval(600), photo: Data([1]))
        let earlier = JournalEntry(id: UUID(), rideID: rideID, title: "Lookout", note: "View", loggedAt: start, photo: nil)

        try repository.save(later)
        try repository.save(earlier)
        try repository.save(JournalEntry(id: UUID(), rideID: UUID(), title: "Other ride", note: "", loggedAt: start, photo: nil))

        XCTAssertEqual(try repository.entries(forRide: rideID), [earlier, later])
    }

    private func makeUseCase() -> AddJournalEntryUseCase {
        AddJournalEntryUseCase(store: store, journal: journal, now: { self.start.addingTimeInterval(600) })
    }
}

/// Keeps entries in memory, and can fail like a full disk would.
private final class MockRideJournalRepository: RideJournalRepository {
    struct StorageFailure: Error {}

    var fails = false
    private(set) var saved: [JournalEntry] = []

    func entries(forRide rideID: UUID) throws -> [JournalEntry] {
        if fails { throw StorageFailure() }
        return saved.filter { $0.rideID == rideID }
    }

    func save(_ entry: JournalEntry) throws {
        if fails { throw StorageFailure() }
        saved.append(entry)
    }

    func eraseAll() throws {
        if fails { throw StorageFailure() }
        saved.removeAll()
    }
}
