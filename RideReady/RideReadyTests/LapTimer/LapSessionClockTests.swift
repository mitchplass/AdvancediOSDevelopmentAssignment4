import Foundation
import Testing
@testable import RideReady

struct LapSessionClockTests {
    private let start = Date(timeIntervalSince1970: 1_000)

    @Test func markLap_recordsTheElapsedTimeAndStartsTheNextLap() {
        var clock = LapSessionClock()
        clock.start(at: start)

        let lap = clock.markLap(at: start.addingTimeInterval(10))

        #expect(lap?.lapNumber == 1)
        #expect(lap?.time == 10)
        #expect(clock.isRunning)
        #expect(clock.currentLapDuration(at: start.addingTimeInterval(16)) == 6)
    }

    @Test func markLap_beforeTheClockStartsDoesNothing() {
        var clock = LapSessionClock()

        #expect(clock.markLap(at: start) == nil)
        #expect(clock.laps.isEmpty)
        #expect(!clock.isRunning)
    }

    @Test func markLap_atTheSameInstantDoesNotRecordALap() {
        var clock = LapSessionClock()
        clock.start(at: start)

        #expect(clock.markLap(at: start) == nil)
        #expect(clock.laps.isEmpty)
        #expect(clock.isRunning)
    }

    @Test func start_aSecondTimeDoesNotResetTheOpenLap() {
        var clock = LapSessionClock()
        clock.start(at: start)
        clock.start(at: start.addingTimeInterval(5))

        #expect(clock.markLap(at: start.addingTimeInterval(10))?.time == 10)
    }

    @Test func markLap_numbersLapsInOrder() {
        var clock = LapSessionClock()
        clock.start(at: start)
        clock.markLap(at: start.addingTimeInterval(10))
        clock.markLap(at: start.addingTimeInterval(25))
        clock.markLap(at: start.addingTimeInterval(40))

        #expect(clock.laps.map(\.lapNumber) == [1, 2, 3])
        #expect(clock.laps.map(\.time) == [10, 15, 15])
    }

    @Test func undoLastLap_putsThatTimeBackOnTheLapThatsRunning() {
        var clock = LapSessionClock()
        clock.start(at: start)
        clock.markLap(at: start.addingTimeInterval(10))
        clock.markLap(at: start.addingTimeInterval(25))

        clock.undoLastLap()

        #expect(clock.laps.map(\.time) == [10])
        #expect(clock.currentLapDuration(at: start.addingTimeInterval(25)) == 15)
    }

    @Test func undoLastLap_whenNothingIsRunningDoesNothing() {
        var clock = LapSessionClock()
        clock.start(at: start)
        clock.markLap(at: start.addingTimeInterval(10))
        _ = clock.finish(at: start.addingTimeInterval(10), keepOpenLap: false)

        clock.undoLastLap()

        #expect(clock.laps.map(\.time) == [10])
        #expect(!clock.isRunning)
    }

    @Test func lapsForSaving_canKeepTheOpenLapWithoutStoppingTheClock() {
        var clock = LapSessionClock()
        clock.start(at: start)
        clock.markLap(at: start.addingTimeInterval(10))

        let saved = clock.lapsForSaving(at: start.addingTimeInterval(25), keepOpenLap: true)

        #expect(saved.map(\.time) == [10, 15])
        #expect(clock.isRunning)
        #expect(clock.laps.map(\.time) == [10])
    }

    @Test func finish_discardsTheOpenLapWhenAsked() {
        var clock = LapSessionClock()
        clock.start(at: start)
        clock.markLap(at: start.addingTimeInterval(10))

        let saved = clock.finish(at: start.addingTimeInterval(25), keepOpenLap: false)

        #expect(saved.map(\.time) == [10])
        #expect(!clock.isRunning)
    }
}

struct LapTimeEntryTests {
    @Test func duration_readsMinutesSecondsAndMilliseconds() {
        let expected = 60 + 23 + 456.0 / 1000
        #expect(LapTimeEntry.duration(minutes: "1", seconds: "23", milliseconds: "456") == expected)
    }

    @Test func duration_treatsABlankFieldAsZero() {
        #expect(LapTimeEntry.duration(minutes: "", seconds: "12", milliseconds: "") == 12)
    }

    @Test func duration_rejectsAnEmptyOrZeroTime() {
        #expect(LapTimeEntry.duration(minutes: "", seconds: "", milliseconds: "") == nil)
        #expect(LapTimeEntry.duration(minutes: "0", seconds: "0", milliseconds: "0") == nil)
    }

    @Test func duration_rejectsSecondsPastFiftyNine() {
        #expect(LapTimeEntry.duration(minutes: "1", seconds: "60", milliseconds: "0") == nil)
    }
}
