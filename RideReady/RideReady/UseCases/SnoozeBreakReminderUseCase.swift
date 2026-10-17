import Foundation

/// Pushes the next break reminder back when the rider can't stop yet.
///
/// Business Rule: the next reminder comes 30 minutes from now; it only
/// applies while riding.
struct SnoozeBreakReminderUseCase {
    static let snoozeLength: TimeInterval = 30 * 60

    let store: RideReadyStoring
    let now: () -> Date

    init(store: RideReadyStoring, now: @escaping () -> Date = Date.init) {
        self.store = store
        self.now = now
    }

    func snooze() throws -> Ride {
        guard var ride = store.activeRide() else {
            throw RideError.noRideInProgress
        }
        guard !ride.isOnBreak else {
            throw RideError.alreadyOnBreak
        }
        ride.remindAgainAt = now().addingTimeInterval(Self.snoozeLength)
        store.save(ride)
        return ride
    }
}
