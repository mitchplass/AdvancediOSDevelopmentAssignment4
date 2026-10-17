import Foundation

/// Loads and saves the motorcycle, walk-arounds, safety streak, rides, and
/// break reminder settings.
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
    /// The ride in progress, if any.
    func activeRide() -> Ride?
    func save(_ ride: Ride)
    /// Finished rides, newest first. Kept so ride history can be summarised later.
    func completedRides() -> [Ride]
    func breakReminderSettings() -> BreakReminderSettings
    func save(_ settings: BreakReminderSettings)
}
