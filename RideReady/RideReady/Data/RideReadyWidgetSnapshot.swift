import Foundation

/// The Home Screen and Lock Screen widget's copy of ride-ready status.
///
/// The widget extension reads the same shape from the App Group. Keep the
/// stored names stable: `bikeName`, `isRideReady`, `detail`, `streakDays`, `ridePhase`.
struct RideReadyWidgetSnapshot: Codable, Equatable {
    var bikeName: String
    var isRideReady: Bool
    var detail: String
    var streakDays: Int
    /// "Riding", "On a break", or "Not riding".
    var ridePhase: String

    static let appGroupID = "group.com.iosdev.RideReady"
    static let storageKey = "rideReady.widgetSnapshot"
    static let kind = "RideReadyWidget"

    static let empty = RideReadyWidgetSnapshot(
        bikeName: "RideReady",
        isRideReady: false,
        detail: "Open RideReady to set up your bike.",
        streakDays: 0,
        ridePhase: "Not riding"
    )

    func writeToAppGroup() {
        guard let defaults = UserDefaults(suiteName: Self.appGroupID),
              let data = try? JSONEncoder().encode(self) else {
            return
        }
        defaults.set(data, forKey: Self.storageKey)
    }

    static func readFromAppGroup() -> RideReadyWidgetSnapshot? {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: storageKey) else {
            return nil
        }
        return try? JSONDecoder().decode(RideReadyWidgetSnapshot.self, from: data)
    }
}
