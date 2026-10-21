import Foundation
import OSLog
import WidgetKit

/// Decorates any repository; replacing UserDefaults with SwiftData need not change the widget.
final class WidgetPublishingRideReadyStore: RideReadyStoring {
    private let base: RideReadyStoring
    private let publish: (RideReadyWidgetSnapshot) -> Void

    init(base: RideReadyStoring, publish: @escaping (RideReadyWidgetSnapshot) -> Void) {
        self.base = base
        self.publish = publish
    }

    convenience init(base: RideReadyStoring) {
        self.init(base: base) { snapshot in
            do {
                if try WidgetSnapshotFile().write(snapshot) {
                    WidgetCenter.shared.reloadTimelines(ofKind: RideReadyWidgetConfiguration.kind)
                }
            } catch {
                Logger(subsystem: "com.iosdev.RideReady", category: "Widget")
                    .error("Widget snapshot could not be saved: \(String(describing: error), privacy: .public)")
            }
        }
    }

    func refreshWidget() {
        publish(BuildWidgetSnapshotUseCase(store: base).execute())
    }

    func motorcycle() -> Motorcycle? { base.motorcycle() }
    func motorcyclePhoto() -> Data? { base.motorcyclePhoto() }
    func activeInspection() -> PreRideInspection? { base.activeInspection() }
    func completedInspections() -> [PreRideInspection] { base.completedInspections() }
    func streak() -> SafetyStreak { base.streak() }
    func activeRide() -> Ride? { base.activeRide() }
    func completedRides() -> [Ride] { base.completedRides() }
    func breakReminderSettings() -> BreakReminderSettings { base.breakReminderSettings() }

    // Forward Lap Timer persistence without changing its existing keys or data model.
    func tracks() -> [Track] { base.tracks() }
    func saveTracks(_ tracks: [Track]) { base.saveTracks(tracks) }
    func sessions() -> [Session] { base.sessions() }
    func saveSessions(_ sessions: [Session]) { base.saveSessions(sessions) }

    func save(_ motorcycle: Motorcycle) {
        base.save(motorcycle)
        refreshWidget()
    }

    func save(_ inspection: PreRideInspection) {
        base.save(inspection)
        refreshWidget()
    }

    func save(_ streak: SafetyStreak) { base.save(streak) }
    func saveMotorcyclePhoto(_ data: Data?) { base.saveMotorcyclePhoto(data) }
    func save(_ ride: Ride) { base.save(ride) }
    func save(_ settings: BreakReminderSettings) { base.save(settings) }

    func eraseAll() {
        base.eraseAll()
        refreshWidget()
    }
}
