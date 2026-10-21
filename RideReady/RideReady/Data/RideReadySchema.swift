import Foundation
import SwiftData

/// Relational store for one motorcycle, its walk-arounds, and the rider's rides.
///
/// Inspections and rides keep their own copy of the facts they need (the bike
/// spec at the time, each finding, each stop) so later edits do not rewrite history.
@Model
final class MotorcycleRecord {
    var id: UUID
    var name: String
    var finalDriveRaw: String
    var frontTyrePressurePSI: Int
    var rearTyrePressurePSI: Int
    var chainSlackMinMillimetres: Int?
    var chainSlackMaxMillimetres: Int?
    var photo: Data?
    @Relationship(deleteRule: .cascade, inverse: \InspectionRecord.motorcycle)
    var inspections: [InspectionRecord] = []

    init(
        id: UUID = UUID(),
        name: String = "",
        finalDriveRaw: String = FinalDrive.chain.rawValue,
        frontTyrePressurePSI: Int = 36,
        rearTyrePressurePSI: Int = 42,
        chainSlackMinMillimetres: Int? = nil,
        chainSlackMaxMillimetres: Int? = nil,
        photo: Data? = nil
    ) {
        self.id = id
        self.name = name
        self.finalDriveRaw = finalDriveRaw
        self.frontTyrePressurePSI = frontTyrePressurePSI
        self.rearTyrePressurePSI = rearTyrePressurePSI
        self.chainSlackMinMillimetres = chainSlackMinMillimetres
        self.chainSlackMaxMillimetres = chainSlackMaxMillimetres
        self.photo = photo
    }
}

@Model
final class InspectionRecord {
    var id: UUID
    var startedAt: Date
    var completedAt: Date?
    var readinessRaw: String?
    var motorcycleName: String
    var finalDriveRaw: String
    var frontTyrePressurePSI: Int
    var rearTyrePressurePSI: Int
    var chainSlackMinMillimetres: Int?
    var chainSlackMaxMillimetres: Int?
    var motorcycle: MotorcycleRecord?
    @Relationship(deleteRule: .cascade, inverse: \FindingRecord.inspection)
    var findings: [FindingRecord] = []

    init(
        id: UUID,
        startedAt: Date,
        completedAt: Date? = nil,
        readinessRaw: String? = nil,
        motorcycleName: String,
        finalDriveRaw: String,
        frontTyrePressurePSI: Int,
        rearTyrePressurePSI: Int,
        chainSlackMinMillimetres: Int? = nil,
        chainSlackMaxMillimetres: Int? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.readinessRaw = readinessRaw
        self.motorcycleName = motorcycleName
        self.finalDriveRaw = finalDriveRaw
        self.frontTyrePressurePSI = frontTyrePressurePSI
        self.rearTyrePressurePSI = rearTyrePressurePSI
        self.chainSlackMinMillimetres = chainSlackMinMillimetres
        self.chainSlackMaxMillimetres = chainSlackMaxMillimetres
    }
}

@Model
final class FindingRecord {
    var sortIndex: Int
    var itemRaw: String
    var resultRaw: String
    var inspection: InspectionRecord?

    init(sortIndex: Int, itemRaw: String, resultRaw: String) {
        self.sortIndex = sortIndex
        self.itemRaw = itemRaw
        self.resultRaw = resultRaw
    }
}

@Model
final class RideRecord {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var remindAgainAt: Date?
    @Relationship(deleteRule: .cascade, inverse: \RideStopRecord.ride)
    var stops: [RideStopRecord] = []

    init(id: UUID, startedAt: Date, endedAt: Date? = nil, remindAgainAt: Date? = nil) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.remindAgainAt = remindAgainAt
    }
}

@Model
final class RideStopRecord {
    var sortIndex: Int
    var startedAt: Date
    var endedAt: Date?
    var ride: RideRecord?

    init(sortIndex: Int, startedAt: Date, endedAt: Date? = nil) {
        self.sortIndex = sortIndex
        self.startedAt = startedAt
        self.endedAt = endedAt
    }
}

@Model
final class SafetyStreakRecord {
    var consecutiveDays: Int
    var lastCompletedOn: Date?

    init(consecutiveDays: Int = 0, lastCompletedOn: Date? = nil) {
        self.consecutiveDays = consecutiveDays
        self.lastCompletedOn = lastCompletedOn
    }
}

@Model
final class BreakReminderSettingsRecord {
    var isEnabled: Bool
    var intervalMinutes: Int

    init(isEnabled: Bool, intervalMinutes: Int) {
        self.isEnabled = isEnabled
        self.intervalMinutes = intervalMinutes
    }
}

@Model
final class TrackRecord {
    var id: UUID
    var name: String
    var location: String
    var lengthMeters: Double?
    var notes: String

    init(id: UUID, name: String, location: String = "", lengthMeters: Double? = nil, notes: String = "") {
        self.id = id
        self.name = name
        self.location = location
        self.lengthMeters = lengthMeters
        self.notes = notes
    }
}

@Model
final class SessionRecord {
    var id: UUID
    var date: Date
    var vehicleID: UUID
    var trackID: UUID
    var weatherRaw: String
    var trackCondition: String
    var setupNotes: String
    @Relationship(deleteRule: .cascade, inverse: \LapRecord.session)
    var laps: [LapRecord] = []

    init(
        id: UUID,
        date: Date,
        vehicleID: UUID,
        trackID: UUID,
        weatherRaw: String,
        trackCondition: String = "",
        setupNotes: String = ""
    ) {
        self.id = id
        self.date = date
        self.vehicleID = vehicleID
        self.trackID = trackID
        self.weatherRaw = weatherRaw
        self.trackCondition = trackCondition
        self.setupNotes = setupNotes
    }
}

@Model
final class LapRecord {
    var sortIndex: Int
    var id: UUID
    var lapNumber: Int
    var time: TimeInterval
    var notes: String
    var session: SessionRecord?

    init(sortIndex: Int, id: UUID, lapNumber: Int, time: TimeInterval, notes: String = "") {
        self.sortIndex = sortIndex
        self.id = id
        self.lapNumber = lapNumber
        self.time = time
        self.notes = notes
    }
}

enum RideReadySchema {
    static let schema = Schema([
        MotorcycleRecord.self,
        InspectionRecord.self,
        FindingRecord.self,
        RideRecord.self,
        RideStopRecord.self,
        SafetyStreakRecord.self,
        BreakReminderSettingsRecord.self,
        TrackRecord.self,
        SessionRecord.self,
        LapRecord.self,
    ])
}
