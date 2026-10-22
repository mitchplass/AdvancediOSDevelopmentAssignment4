//
//  Protocols.swift
//

import Foundation

// MARK: - PersistableEntity

protocol PersistableEntity: Codable, Identifiable, Hashable {
    var id: UUID { get }
}

// MARK: - TimeFormattable

/// Formats a duration (in seconds) the way a racer expects to see a lap time on a timing screen or stopwatch: minutes:seconds.milliseconds,  e.g. "1:23.456".
protocol TimeFormattable {
    var formattedTime: String { get }
}

extension TimeInterval: TimeFormattable {
    var formattedTime: String {
        let totalMilliseconds = Int((self * 1000).rounded())
        let minutes = totalMilliseconds / 60_000
        let seconds = (totalMilliseconds / 1000) % 60
        let milliseconds = totalMilliseconds % 1000
        return String(format: "%d:%02d.%03d", minutes, seconds, milliseconds)
    }
}

extension TimeInterval {
    /// Parses a lap time typed by the user. Accepts either "mm:ss.SSS" (e.g. "1:23.456") or a plain number of seconds (e.g. "83.456").

    init?(fromLapString string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.contains(":") {
            let parts = trimmed.split(separator: ":")
            guard parts.count == 2,
                  let minutes = Double(parts[0]),
                  let seconds = Double(parts[1]),
                  minutes >= 0, seconds >= 0 else { return nil }
            self = minutes * 60 + seconds
        } else {
            guard let seconds = Double(trimmed), seconds >= 0 else { return nil }
            self = seconds
        }
    }
}

// MARK: - LapStatisticsProviding

protocol LapStatisticsProviding {
    var laps: [Lap] { get }
}

extension LapStatisticsProviding {
    var fastestLap: Lap? {
        laps.min { $0.time < $1.time }
    }

    var averageLapTime: TimeInterval? {
        guard !laps.isEmpty else { return nil }
        let total = laps.reduce(0) { $0 + $1.time }
        return total / Double(laps.count)
    }

    var lapCount: Int {
        laps.count
    }

    var consistency: TimeInterval? {
        guard laps.count > 1, let average = averageLapTime else { return nil }
        let squaredDifferences = laps.reduce(0.0) { partial, lap in
            let difference = lap.time - average
            return partial + (difference * difference)
        }
        let variance = squaredDifferences / Double(laps.count)
        return variance.squareRoot()
    }
}

// MARK: - TrackDayEventRecord

protocol TrackDayEventRecord {
    var eventDate: Date { get }

    func eventSummary(vehicleName: String, trackName: String) -> String
}

// MARK: - PersistenceStore

protocol PersistenceStore {
    associatedtype Entity: PersistableEntity
    func loadAll() -> [Entity]
    func save(_ items: [Entity])
}
