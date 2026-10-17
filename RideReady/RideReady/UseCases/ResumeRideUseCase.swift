import Foundation

/// Ends the current stop when the rider is back on the road.
///
/// Business Rule: a stop of 15 minutes or more resets the riding clock; a
/// shorter stop only paused it (see `Ride`).
struct ResumeRideUseCase {
    let store: RideReadyStoring
    let now: () -> Date

    init(store: RideReadyStoring, now: @escaping () -> Date = Date.init) {
        self.store = store
        self.now = now
    }

    func resume() throws -> Ride {
        guard var ride = store.activeRide() else {
            throw RideError.noRideInProgress
        }
        guard ride.isOnBreak, let index = ride.stops.indices.last else {
            throw RideError.notOnBreak
        }
        ride.stops[index].endedAt = now()
        store.save(ride)
        return ride
    }
}
