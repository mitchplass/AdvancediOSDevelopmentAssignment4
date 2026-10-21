import XCTest
@testable import RideReady

final class WidgetAppearanceSyncTests: XCTestCase {
    func testSharedPreferenceDefaultsToSystem() {
        let defaults = UserDefaults(suiteName: "test.rideready.appearance.\(UUID().uuidString)")!
        XCTAssertEqual(WidgetAppearancePreference.read(from: defaults), .system)
    }

    func testAppearanceChoiceIsSharedAndChangesReloadableValue() {
        let name = "test.rideready.appearance.\(UUID().uuidString)"
        let widgetDefaults = UserDefaults(suiteName: name)!
        defer { widgetDefaults.removePersistentDomain(forName: name) }
        let appDefaults = UserDefaults(suiteName: "test.rideready.app.\(UUID().uuidString)")!
        let settings = AppearanceSettings(defaults: appDefaults, widgetDefaults: widgetDefaults)
        XCTAssertEqual(WidgetAppearancePreference.read(from: widgetDefaults), .system)

        settings.mode = .dark
        XCTAssertEqual(WidgetAppearancePreference.read(from: widgetDefaults), .dark)
        settings.mode = .light
        XCTAssertEqual(WidgetAppearancePreference.read(from: widgetDefaults), .light)
        settings.mode = .system
        XCTAssertEqual(WidgetAppearancePreference.read(from: widgetDefaults), .system)
    }

    func testUnknownStoredValueFallsBackToSystem() {
        let name = "test.rideready.badvalue.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set("not-a-mode", forKey: WidgetAppearancePreference.storageKey)
        XCTAssertEqual(WidgetAppearancePreference.read(from: defaults), .system)
        XCTAssertTrue(WidgetAppearancePreference.write(.light, to: defaults))
        XCTAssertFalse(WidgetAppearancePreference.write(.light, to: defaults))
    }
}
