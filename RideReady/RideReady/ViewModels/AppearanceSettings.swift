import Combine
import Foundation

/// The rider's light or dark choice, remembered between launches.
final class AppearanceSettings: ObservableObject {
    static let storageKey = "rideReady.appearanceMode"

    @Published var mode: AppearanceMode {
        didSet { defaults.set(mode.rawValue, forKey: Self.storageKey) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.string(forKey: Self.storageKey) ?? ""
        mode = AppearanceMode(rawValue: stored) ?? .system
    }
}
