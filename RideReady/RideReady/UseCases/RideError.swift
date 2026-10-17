import Foundation

/// Failures when Alex starts, pauses, or ends a ride.
enum RideError: LocalizedError, Equatable {
    case rideInProgress
    case noRideInProgress
    case alreadyOnBreak
    case notOnBreak

    var errorDescription: String? {
        switch self {
        case .rideInProgress:
            return "You already have a ride in progress. End it before you start another."
        case .noRideInProgress:
            return "You haven't started a ride yet. Tap Start ride when you head off."
        case .alreadyOnBreak:
            return "You're already on a break. Tap Back on the road when you set off again."
        case .notOnBreak:
            return "You're not on a break right now."
        }
    }
}
