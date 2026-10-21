import Foundation
import WidgetKit

/// Publishes today's ride-ready status for the widget after the store changes.
enum RideReadyWidgetPublisher {
    static func publish(from store: RideReadyStoring, now: Date = Date(), calendar: Calendar = .current) {
        snapshot(from: store, now: now, calendar: calendar).writeToAppGroup()
        WidgetCenter.shared.reloadTimelines(ofKind: RideReadyWidgetSnapshot.kind)
    }

    static func snapshot(
        from store: RideReadyStoring,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> RideReadyWidgetSnapshot {
        let bikeName = store.motorcycle()?.name ?? "No bike set up"
        let streakDays = store.streak().consecutiveDays
        let ridePhase: String
        if let ride = store.activeRide() {
            ridePhase = ride.isOnBreak ? "On a break" : "Riding"
        } else {
            ridePhase = "Not riding"
        }

        if store.activeInspection() != nil {
            return RideReadyWidgetSnapshot(
                bikeName: bikeName,
                isRideReady: false,
                detail: "Finish the walk-around before you leave.",
                streakDays: streakDays,
                ridePhase: ridePhase
            )
        }

        if let latest = store.completedInspections().first,
           latest.readiness == .readyToRide,
           let completedAt = latest.completedAt,
           calendar.isDate(completedAt, inSameDayAs: now) {
            return RideReadyWidgetSnapshot(
                bikeName: bikeName,
                isRideReady: true,
                detail: "All checks passed today.",
                streakDays: streakDays,
                ridePhase: ridePhase
            )
        }

        let detail = store.completedInspections().first?.readiness == .notRideReady
            ? "Last walk-around needs attention."
            : "Do a pre-ride check before you leave."
        return RideReadyWidgetSnapshot(
            bikeName: bikeName,
            isRideReady: false,
            detail: detail,
            streakDays: streakDays,
            ridePhase: ridePhase
        )
    }
}
