import Foundation

/// A stop during a ride, from "Take a break" to "Back on the road".
struct RideStop: Codable, Equatable {
    let startedAt: Date
    var endedAt: Date?

    func duration(at date: Date) -> TimeInterval {
        (endedAt ?? date).timeIntervalSince(startedAt)
    }
}

/// One ride, from Start ride to End ride.
///
/// Business Rules:
/// - Riding time pauses during stops.
/// - A stop of 15 minutes or more is a full rest and resets the riding clock;
///   a shorter stop (fuel, a photo) only pauses it.
struct Ride: Codable, Equatable {
    static let fullRest: TimeInterval = 15 * 60

    let id: UUID
    let startedAt: Date
    var endedAt: Date?
    var stops: [RideStop]
    /// Set by "Remind me in 30 min"; the next break reminder waits until then.
    var remindAgainAt: Date?

    var isOnBreak: Bool {
        guard let last = stops.last else { return false }
        return last.endedAt == nil
    }

    var currentStop: RideStop? {
        isOnBreak ? stops.last : nil
    }

    /// Riding time since the ride started or since the last full rest.
    func ridingTimeSinceRest(at date: Date) -> TimeInterval {
        stints(at: date).last ?? 0
    }

    /// Riding time for the whole ride, with every stop taken out.
    func totalRidingTime(at date: Date) -> TimeInterval {
        stints(at: date).reduce(0, +)
    }

    /// The longest stretch of riding between full rests.
    func longestStint(at date: Date) -> TimeInterval {
        stints(at: date).max() ?? 0
    }

    /// Riding time of each stretch between full rests. A stop that has
    /// already lasted 15 minutes ends the stretch, even while it is going.
    private func stints(at date: Date) -> [TimeInterval] {
        let end = endedAt ?? date
        var stints: [TimeInterval] = []
        var current: TimeInterval = 0
        var ridingSince: Date? = startedAt

        for stop in stops {
            if let ridingSince {
                current += max(0, stop.startedAt.timeIntervalSince(ridingSince))
            }
            if stop.duration(at: end) >= Self.fullRest {
                stints.append(current)
                current = 0
            }
            ridingSince = stop.endedAt
        }
        if let ridingSince {
            current += max(0, end.timeIntervalSince(ridingSince))
        }
        stints.append(current)
        return stints
    }
}

/// How often the rider wants a break reminder while riding.
///
/// Business Rule: the interval is 30 minutes to 4 hours, in 15-minute steps.
struct BreakReminderSettings: Codable, Equatable {
    static let intervalRange = 30...240
    static let intervalStep = 15

    var isEnabled: Bool
    var intervalMinutes: Int

    static let standard = BreakReminderSettings(isEnabled: true, intervalMinutes: 120)
}

/// Short ride durations: "45 min", "2 h", "2 h 15 m". Elapsed time rounds
/// down; time left rounds up, so a fresh 2-hour countdown reads "2 h".
enum DurationText {
    static func string(for interval: TimeInterval, roundingUp: Bool = false) -> String {
        let wholeMinutes = roundingUp ? (interval / 60).rounded(.up) : (interval / 60).rounded(.down)
        let totalMinutes = max(0, Int(wholeMinutes))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 {
            return "\(minutes) min"
        }
        if minutes == 0 {
            return "\(hours) h"
        }
        return "\(hours) h \(minutes) m"
    }
}
