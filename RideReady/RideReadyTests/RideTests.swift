import XCTest
@testable import RideReady

final class RideTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    func test_shortStop_pausesRidingClockWithoutResettingIt() {
        let ride = makeRide(stops: [stop(from: 60, to: 65)])

        let now = minutes(95)

        XCTAssertEqual(ride.ridingTimeSinceRest(at: now), 90 * 60)
        XCTAssertEqual(ride.totalRidingTime(at: now), 90 * 60)
    }

    func test_fullRest_resetsRidingClock() {
        let ride = makeRide(stops: [stop(from: 60, to: 80)])

        let now = minutes(110)

        XCTAssertEqual(ride.ridingTimeSinceRest(at: now), 30 * 60)
        XCTAssertEqual(ride.totalRidingTime(at: now), 90 * 60)
        XCTAssertEqual(ride.longestStint(at: now), 60 * 60)
    }

    func test_breakInProgress_resetsClockOnceItReachesFifteenMinutes() {
        let ride = makeRide(stops: [RideStop(startedAt: minutes(100), endedAt: nil)])

        XCTAssertEqual(ride.ridingTimeSinceRest(at: minutes(110)), 100 * 60)
        XCTAssertEqual(ride.ridingTimeSinceRest(at: minutes(115)), 0)
        XCTAssertEqual(ride.totalRidingTime(at: minutes(115)), 100 * 60)
    }

    private func makeRide(stops: [RideStop]) -> Ride {
        Ride(id: UUID(), startedAt: start, endedAt: nil, stops: stops, remindAgainAt: nil)
    }

    private func stop(from startMinute: Double, to endMinute: Double) -> RideStop {
        RideStop(startedAt: minutes(startMinute), endedAt: minutes(endMinute))
    }

    private func minutes(_ value: Double) -> Date {
        start.addingTimeInterval(value * 60)
    }
}
