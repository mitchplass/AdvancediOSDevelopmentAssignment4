import Foundation

/// The widget cannot observe the app's normal UserDefaults container.
/// Store the appearance choice in the same App Group as the inspection snapshot.
enum WidgetAppearancePreference: String, Equatable {
    case system
    case light
    case dark

    static let storageKey = "rideReady.appearanceMode"

    static func groupDefaults(bundle: Bundle = .main) -> UserDefaults? {
        guard let group = bundle.object(forInfoDictionaryKey: "RideReadyAppGroup") as? String,
              !group.isEmpty, !group.contains("$(") else { return nil }
        return UserDefaults(suiteName: group)
    }

    static func read(from defaults: UserDefaults?) -> Self {
        guard let stored = defaults?.string(forKey: storageKey) else { return .system }
        return Self(rawValue: stored) ?? .system
    }

    /// Returns true only if the stored choice actually changed.
    @discardableResult
    static func write(_ mode: Self, to defaults: UserDefaults?) -> Bool {
        guard let defaults else { return false }
        guard defaults.string(forKey: storageKey) != mode.rawValue else { return false }
        defaults.set(mode.rawValue, forKey: storageKey)
        return true
    }
}
