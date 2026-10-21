import Combine
import Foundation
import WidgetKit

/// The appearance setting shared by all in-app tabs and the home screen widget.
final class AppearanceSettings: ObservableObject {
    static let storageKey = "rideReady.appearanceMode"

    @Published var mode: AppearanceMode {
        didSet {
            defaults.set(mode.rawValue, forKey: Self.storageKey)
            publishToWidget()
        }
    }

    private let defaults: UserDefaults
    private let widgetDefaults: UserDefaults?

    init(defaults: UserDefaults = .standard,
         widgetDefaults: UserDefaults? = WidgetAppearancePreference.groupDefaults()) {
        self.defaults = defaults
        self.widgetDefaults = widgetDefaults
        let stored = defaults.string(forKey: Self.storageKey) ?? ""
        mode = AppearanceMode(rawValue: stored) ?? .system
        // Migrate existing local preferences when this widget version is first installed.
        publishToWidget()
    }

    private func publishToWidget() {
        let sharedMode = WidgetAppearancePreference(rawValue: mode.rawValue) ?? .system
        if WidgetAppearancePreference.write(sharedMode, to: widgetDefaults) {
            WidgetCenter.shared.reloadTimelines(ofKind: RideReadyWidgetConfiguration.kind)
        }
    }
}
