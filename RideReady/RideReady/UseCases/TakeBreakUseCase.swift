import Foundation

/// Starts a stop during the ride: a rest, fuel, or a photo.
///
/// Business Rule: the ride must be in progress and not already stopped.
/// Break reminders pause until the rider is back on the road.
struct TakeBreakUseCase {
    let store: RideReadyStoring
    let now: () -> Date

    init(store: RideReadyStoring, now: @escaping () -> Date = Date.init) {
        self.store = store
        self.now = now
    }

    func takeBreak() throws -> Ride {
        guard var ride = store.activeRide() else {
            throw RideError.noRideInProgress
        }
        guard !ride.isOnBreak else {
            throw RideError.alreadyOnBreak
        }
        ride.stops.append(RideStop(startedAt: now(), endedAt: nil))
        ride.remindAgainAt = nil
        store.save(ride)
        return ride
    }
}
