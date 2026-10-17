import Foundation

/// Loads and saves the motorcycle, walk-arounds, and safety streak.
///
/// Business Rule: an inspection cannot start without a motorcycle profile.
protocol RideReadyStoring {
    func motorcycle() -> Motorcycle?
    func save(_ motorcycle: Motorcycle)
    func motorcyclePhoto() -> Data?
    func saveMotorcyclePhoto(_ data: Data?)
    func activeInspection() -> PreRideInspection?
    func save(_ inspection: PreRideInspection)
    /// Finished walk-arounds, newest first.
    func completedInspections() -> [PreRideInspection]
    func streak() -> SafetyStreak
    func save(_ streak: SafetyStreak)
}
