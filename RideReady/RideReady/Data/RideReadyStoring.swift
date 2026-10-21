import Foundation

/// Loads and saves the motorcycle, walk-arounds, safety streak, rides, break
/// reminder settings, and the lap timer's tracks and sessions.
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
    /// Lap timer circuits.
    func tracks() -> [Track]
    func saveTracks(_ tracks: [Track])
    /// Lap timer sessions, each with its lap times.
    func sessions() -> [Session]
    func saveSessions(_ sessions: [Session])
    /// Deletes the motorcycle, photo, walk-arounds, streak, rides, reminder settings, tracks, and sessions.
    func eraseAll()
}

// MARK: - Lap timer stores
//
// The lap timer's use cases work on a `PersistenceStore` per entity. These
// adapters point each one at `RideReadyStoring`, so the lap timer shares the
// app's single store instead of keeping its own.

extension Vehicle {
    /// RideReady stores exactly one motorcycle and gives it no identity of its
    /// own, so sessions point at this fixed ID. The bike's name is always read
    /// live from the store, which means renaming the bike in the Bike tab
    /// updates every recorded session.
    static let rideReadyMotorcycleID = UUID(uuidString: "5B1E7C2A-4D3F-4E8A-9A61-2F0C7B8D1E54")!

    init(rideReadyMotorcycle motorcycle: Motorcycle) {
        self.init(id: Vehicle.rideReadyMotorcycleID, name: motorcycle.name, type: .motorcycle)
    }
}

/// The RideReady motorcycle as the lap timer's only vehicle.
///
/// Business Rule: bikes are added and edited in the Bike tab only. `save` does
/// nothing so the lap timer can never create a second, diverging bike list.
struct RideReadyVehicleStore: PersistenceStore {
    let store: RideReadyStoring

    func loadAll() -> [Vehicle] {
        guard let motorcycle = store.motorcycle() else { return [] }
        return [Vehicle(rideReadyMotorcycle: motorcycle)]
    }

    func save(_ items: [Vehicle]) {}
}

struct RideReadyTrackStore: PersistenceStore {
    let store: RideReadyStoring

    func loadAll() -> [Track] { store.tracks() }
    func save(_ items: [Track]) { store.saveTracks(items) }
}

struct RideReadySessionStore: PersistenceStore {
    let store: RideReadyStoring

    func loadAll() -> [Session] { store.sessions() }
    func save(_ items: [Session]) { store.saveSessions(items) }
}
