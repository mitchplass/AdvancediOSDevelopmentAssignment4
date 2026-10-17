import Foundation

/// Starts a ride so RideReady can time it and remind the rider to take breaks.
///
/// Business Rule: only one ride can be in progress.
struct StartRideUseCase {
    let store: RideReadyStoring
    let now: () -> Date

    init(store: RideReadyStoring, now: @escaping () -> Date = Date.init) {
        self.store = store
        self.now = now
    }

    func start() throws -> Ride {
        guard store.activeRide() == nil else {
            throw RideError.rideInProgress
        }
        let ride = Ride(id: UUID(), startedAt: now(), endedAt: nil, stops: [], remindAgainAt: nil)
        store.save(ride)
        return ride
    }
}
