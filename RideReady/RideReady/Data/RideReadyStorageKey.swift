import Foundation

/// UserDefaults keys that are preferences, not the motorcycle domain store.
enum RideReadyStorageKey {
    /// Set after the rider erases ride data, so the sample bike does not return.
    static let suppressSampleMotorcycle = "rideReady.suppressSampleMotorcycle"
    /// Set once the UserDefaults store has been copied into SwiftData.
    static let didMigrateToSwiftData = "rideReady.didMigrateToSwiftData"
}
