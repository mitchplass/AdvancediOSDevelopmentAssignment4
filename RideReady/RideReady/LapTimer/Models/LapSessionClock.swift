import Foundation

/// A stopwatch for one outing. Marking a lap stores its duration and starts the next one.
struct LapSessionClock {
    private(set) var laps: [Lap] = []
    private(set) var lapStartedAt: Date?

    var isRunning: Bool { lapStartedAt != nil }

    mutating func start(at date: Date) {
        guard lapStartedAt == nil else { return }
        lapStartedAt = date
    }

    func currentLapDuration(at date: Date) -> TimeInterval {
        guard let lapStartedAt else { return 0 }
        return max(0, date.timeIntervalSince(lapStartedAt))
    }

    /// Records the open lap when it has a positive duration, then starts the next lap.
    @discardableResult
    mutating func markLap(at date: Date) -> Lap? {
        guard let start = lapStartedAt else { return nil }
        let duration = date.timeIntervalSince(start)
        guard duration > 0 else { return nil }
        let lap = Lap(lapNumber: laps.count + 1, time: duration)
        laps.append(lap)
        lapStartedAt = date
        return lap
    }

    /// Drops the most recent lap and keeps its time on the lap that's running.
    mutating func undoLastLap() {
        guard let removed = laps.last, let start = lapStartedAt else { return }
        laps.removeLast()
        lapStartedAt = start.addingTimeInterval(-removed.time)
    }

    func lapsForSaving(at date: Date, keepOpenLap: Bool) -> [Lap] {
        var copy = self
        return copy.finish(at: date, keepOpenLap: keepOpenLap)
    }

    mutating func finish(at date: Date, keepOpenLap: Bool) -> [Lap] {
        if keepOpenLap {
            _ = markLap(at: date)
        }
        lapStartedAt = nil
        return laps
    }
}

/// Reads minutes, seconds, and milliseconds typed as separate fields.
enum LapTimeEntry {
    static func duration(minutes: String, seconds: String, milliseconds: String) -> TimeInterval? {
        let anyFilled = [minutes, seconds, milliseconds].contains { part in
            !part.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard anyFilled,
              let minutes = part(minutes, range: 0...999),
              let seconds = part(seconds, range: 0...59),
              let milliseconds = part(milliseconds, range: 0...999) else {
            return nil
        }
        let time = Double(minutes) * 60 + Double(seconds) + Double(milliseconds) / 1000
        return time > 0 ? time : nil
    }

    private static func part(_ text: String, range: ClosedRange<Int>) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return 0 }
        guard let value = Int(trimmed), range.contains(value) else { return nil }
        return value
    }
}
