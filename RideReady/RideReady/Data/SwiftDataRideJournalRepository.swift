import Foundation
import SwiftData

/// One ride's journal on disk. Its entries are deleted with it.
@Model
final class RideJournalRecord {
    @Attribute(.unique) var rideID: UUID
    @Relationship(deleteRule: .cascade, inverse: \JournalEntryRecord.journal)
    var entries: [JournalEntryRecord] = []

    init(rideID: UUID) {
        self.rideID = rideID
    }
}

@Model
final class JournalEntryRecord {
    @Attribute(.unique) var entryID: UUID
    var title: String
    var note: String
    var loggedAt: Date
    /// Kept outside the database file so large photos don't slow queries.
    @Attribute(.externalStorage) var photo: Data?
    var journal: RideJournalRecord?

    init(_ entry: JournalEntry) {
        entryID = entry.id
        title = entry.title
        note = entry.note
        loggedAt = entry.loggedAt
        photo = entry.photo
    }
}

/// Saves ride journal entries with SwiftData.
final class SwiftDataRideJournalRepository: RideJournalRepository {
    private let context: ModelContext

    /// Pass `inMemory: true` for tests.
    init(inMemory: Bool = false) throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        let container = try ModelContainer(
            for: RideJournalRecord.self, JournalEntryRecord.self,
            configurations: configuration
        )
        context = ModelContext(container)
    }

    func entries(forRide rideID: UUID) throws -> [JournalEntry] {
        let descriptor = FetchDescriptor<JournalEntryRecord>(
            predicate: #Predicate { $0.journal?.rideID == rideID },
            sortBy: [SortDescriptor(\.loggedAt)]
        )
        return try context.fetch(descriptor).map { record in
            JournalEntry(
                id: record.entryID,
                rideID: rideID,
                title: record.title,
                note: record.note,
                loggedAt: record.loggedAt,
                photo: record.photo
            )
        }
    }

    func save(_ entry: JournalEntry) throws {
        let rideID = entry.rideID
        var descriptor = FetchDescriptor<RideJournalRecord>(predicate: #Predicate { $0.rideID == rideID })
        descriptor.fetchLimit = 1
        let journal: RideJournalRecord
        if let existing = try context.fetch(descriptor).first {
            journal = existing
        } else {
            journal = RideJournalRecord(rideID: rideID)
            context.insert(journal)
        }
        let record = JournalEntryRecord(entry)
        context.insert(record)
        record.journal = journal
        try context.save()
    }

    func eraseAll() throws {
        for record in try context.fetch(FetchDescriptor<JournalEntryRecord>()) {
            context.delete(record)
        }
        for record in try context.fetch(FetchDescriptor<RideJournalRecord>()) {
            context.delete(record)
        }
        try context.save()
    }
}
