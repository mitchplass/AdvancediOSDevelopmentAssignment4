import Foundation

/// Loads and saves the journal entries logged during rides.
protocol RideJournalRepository {
    /// The ride's entries, oldest first.
    func entries(forRide rideID: UUID) throws -> [JournalEntry]
    func save(_ entry: JournalEntry) throws
    /// Deletes every journal entry on this iPhone.
    func eraseAll() throws
}
