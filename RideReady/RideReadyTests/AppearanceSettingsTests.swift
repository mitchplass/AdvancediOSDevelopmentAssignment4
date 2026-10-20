import SwiftUI
import XCTest
@testable import RideReady

final class AppearanceSettingsTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        suiteName = "RideReadyTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
    }

    func test_defaultsToSystem() {
        let settings = AppearanceSettings(defaults: defaults)

        XCTAssertEqual(settings.mode, .system)
        XCTAssertNil(settings.mode.colorScheme)
    }

    func test_persistsLightAndDark() {
        let settings = AppearanceSettings(defaults: defaults)

        settings.mode = .dark
        XCTAssertEqual(AppearanceSettings(defaults: defaults).mode, .dark)
        XCTAssertEqual(settings.mode.colorScheme, .dark)

        settings.mode = .light
        XCTAssertEqual(AppearanceSettings(defaults: defaults).mode, .light)
        XCTAssertEqual(settings.mode.colorScheme, .light)
    }

    func test_unknownStoredValueFallsBackToSystem() {
        defaults.set("sepia", forKey: AppearanceSettings.storageKey)

        XCTAssertEqual(AppearanceSettings(defaults: defaults).mode, .system)
    }

    func test_colorSchemeMatchesTheChoice() {
        XCTAssertNil(AppearanceMode.system.colorScheme)
        XCTAssertEqual(AppearanceMode.light.colorScheme, .light)
        XCTAssertEqual(AppearanceMode.dark.colorScheme, .dark)
    }
}
