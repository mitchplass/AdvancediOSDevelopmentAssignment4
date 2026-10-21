import XCTest
@testable import RideReady

final class WidgetRoutingTests: XCTestCase {
    @MainActor
    func test_checkLinkFromRideTabStartsOnceAndRoutesToBikeChecklist() async throws {
        let store = WidgetTestStore()
        store.bike = .yamahaMT07()
        let router = AppRouter()
        router.selectedTab = .ride
        XCTAssertTrue(router.openWidgetURL(RideReadyWidgetConfiguration.checkURL, store: store))
        XCTAssertEqual(router.selectedTab, .bike)
        XCTAssertEqual(router.bikePath, [.checklist])
        let firstID = try XCTUnwrap(store.activeInspection()?.id)
        router.openWidgetURL(RideReadyWidgetConfiguration.checkURL, store: store)
        XCTAssertEqual(store.activeInspection()?.id, firstID)
        XCTAssertEqual(router.bikePath, [.checklist])
    }

    @MainActor
    func test_noMotorcycleRoutesToSetupWithoutStartingInspection() async {
        let store = WidgetTestStore()
        let router = AppRouter()
        router.openWidgetURL(RideReadyWidgetConfiguration.checkURL, store: store)
        XCTAssertEqual(router.bikePath, [.bikeProfile])
        XCTAssertNil(store.activeInspection())
    }

    @MainActor
    func test_historyLinkSwitchesTabAndPopsToBikeRootWithoutChangingCheck() async throws {
        let store = WidgetTestStore()
        store.bike = .yamahaMT07()
        let active = try StartPreRideInspectionUseCase(store: store).start()
        let router = AppRouter()
        router.selectedTab = .ride
        router.bikePath = [.bikeProfile]
        router.openWidgetURL(RideReadyWidgetConfiguration.homeURL, store: store)
        XCTAssertEqual(router.selectedTab, .bike)
        XCTAssertTrue(router.bikePath.isEmpty)
        XCTAssertEqual(store.activeInspection()?.id, active.id)
    }

    @MainActor
    func test_unknownURLDoesNotChangeExistingNavigationOrData() async {
        let store = WidgetTestStore()
        let router = AppRouter()
        router.selectedTab = .ride
        router.bikePath = [.bikeProfile]
        XCTAssertFalse(router.openWidgetURL(URL(string: "rideready://delete")!, store: store))
        XCTAssertEqual(router.selectedTab, .ride)
        XCTAssertEqual(router.bikePath, [.bikeProfile])
        XCTAssertNil(store.activeInspection())
    }
}
