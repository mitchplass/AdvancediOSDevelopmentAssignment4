//
//  RecordTrackDaySessionUseCase.swift
//

import Foundation

struct RecordTrackDaySessionUseCase<
    VehicleStore: PersistenceStore,
    TrackStore: PersistenceStore,
    SessionStore: PersistenceStore
> where VehicleStore.Entity == Vehicle, TrackStore.Entity == Track, SessionStore.Entity == Session {
    let vehicleStore: VehicleStore
    let trackStore: TrackStore
    let sessionStore: SessionStore
    private let now: () -> Date

    init(
        vehicleStore: VehicleStore,
        trackStore: TrackStore,
        sessionStore: SessionStore,
        now: @escaping () -> Date = Date.init
    ) {
        self.vehicleStore = vehicleStore
        self.trackStore = trackStore
        self.sessionStore = sessionStore
        self.now = now
    }

    /// Records a new session, validating it against RaceLog's recording rules first.
    /// Throws: `TrackDaySessionError` if the vehicle or track isn't registered, the date is in the future, no laps were supplied or any individual lap time isn't a positive duration.
 
    @discardableResult
    func execute(
        vehicleID: UUID,
        trackID: UUID,
        date: Date,
        weather: WeatherCondition,
        trackCondition: String,
        setupNotes: String,
        laps: [Lap]
    ) throws -> Session {
        guard vehicleStore.loadAll().contains(where: { $0.id == vehicleID }) else {
            throw TrackDaySessionError.vehicleNotRegistered(vehicleID: vehicleID)
        }

        guard trackStore.loadAll().contains(where: { $0.id == trackID }) else {
            throw TrackDaySessionError.trackNotRegistered(trackID: trackID)
        }

        guard date <= now() else {
            throw TrackDaySessionError.sessionDateInFuture(date: date)
        }

        guard !laps.isEmpty else {
            throw TrackDaySessionError.noLapsRecorded
        }

        if let invalidLap = laps.first(where: { $0.time <= 0 }) {
            throw TrackDaySessionError.invalidLapTime(lapNumber: invalidLap.lapNumber, seconds: invalidLap.time)
        }

        let session = Session(
            date: date,
            vehicleID: vehicleID,
            trackID: trackID,
            weather: weather,
            trackCondition: trackCondition,
            setupNotes: setupNotes,
            laps: laps
        )
        sessionStore.save(sessionStore.loadAll() + [session])
        return session
    }
}

enum TrackDaySessionError: LocalizedError, Equatable {
    /// Who hits this: a racer tries to log a session against a vehicle that was deleted, or never registered.
    /// Recovery: register the vehicle first, then log the session.
    case vehicleNotRegistered(vehicleID: UUID)

    /// Who hits this: a racer tries to log a session against a track that was deleted, or never registered.
    /// Recovery: register the track first, then log the session.
    case trackNotRegistered(trackID: UUID)

    /// Who hits this: a racer picks a session date that hasn't happened yet.
    /// Recovery: log the session once the outing has actually taken place.
    case sessionDateInFuture(date: Date)

    /// Who hits this: a racer tries to save a session with no lap times entered.
    /// Recovery: add at least one lap time before saving.
    case noLapsRecorded

    /// Who hits this: a racer enters a lap time that's zero or negative (typically a data-entry mistake).
    /// Recovery: correct the affected lap's time.
    case invalidLapTime(lapNumber: Int, seconds: TimeInterval)

    var errorDescription: String? {
        switch self {
        case .vehicleNotRegistered:
            return "Set up your bike in the Bike tab before timing a session."
        case .trackNotRegistered:
            return "Add this track before timing a session there."
        case .sessionDateInFuture:
            return "Pick a date that isn't in the future."
        case .noLapsRecorded:
            return "Add at least one lap before saving."
        case .invalidLapTime(let lapNumber, _):
            return "Lap \(lapNumber) needs a time greater than zero."
        }
    }
}
