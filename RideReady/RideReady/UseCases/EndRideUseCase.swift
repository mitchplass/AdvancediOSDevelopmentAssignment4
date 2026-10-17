import Foundation

/// Finishes the ride in progress.
///
/// Business Rule: ending a ride while stopped also ends that stop, so the
/// ride's times add up.
struct EndRideUseCase {
    let store: RideReadyStoring
    let now: () -> Date

    init(store: RideReadyStoring, now: @escaping () -> Date = Date.init) {
        self.store = store
        self.now = now
    }

    func end() throws -> Ride {
        guard var ride = store.activeRide() else {
            throw RideError.noRideInProgress
        }
        let endedAt = now()
        if ride.isOnBreak, let index = ride.stops.indices.last {
            ride.stops[index].endedAt = endedAt
        }
        ride.endedAt = endedAt
        ride.remindAgainAt = nil
        store.save(ride)
        return ride
    }
}
