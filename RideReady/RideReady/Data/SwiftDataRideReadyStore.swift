import Foundation
import os
import SwiftData

/// SwiftData implementation of the ride store.
///
/// The model context is used on the main thread. Callers that are already
/// off the main thread, such as a notification action, hop over and wait.
final class SwiftDataRideReadyStore: RideReadyStoring {
    private let container: ModelContainer
    private static let logger = Logger(subsystem: "com.iosdev.RideReady", category: "store")

    init(inMemory: Bool = false) throws {
        let name = inMemory ? "RideReady-\(UUID().uuidString)" : "RideReady"
        let configuration = ModelConfiguration(
            name,
            schema: RideReadySchema.schema,
            isStoredInMemoryOnly: inMemory,
            groupContainer: .none,
            cloudKitDatabase: .none
        )
        container = try ModelContainer(for: RideReadySchema.schema, configurations: [configuration])
    }

    /// Copies the previous UserDefaults store once. Later launches leave SwiftData as the source of truth.
    func migrateFromUserDefaultsIfNeeded(defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: RideReadyStorageKey.didMigrateToSwiftData) else { return }
        let legacy = UserDefaultsRideReadyStore(defaults: defaults)
        if let motorcycle = legacy.motorcycle() {
            save(motorcycle)
            saveMotorcyclePhoto(legacy.motorcyclePhoto())
        }
        for inspection in legacy.completedInspections() {
            save(inspection)
        }
        if let activeInspection = legacy.activeInspection() {
            save(activeInspection)
        }
        save(legacy.streak())
        if let activeRide = legacy.activeRide() {
            save(activeRide)
        }
        for ride in legacy.completedRides() {
            save(ride)
        }
        save(legacy.breakReminderSettings())
        let tracks = legacy.tracks()
        if !tracks.isEmpty {
            saveTracks(tracks)
        }
        let sessions = legacy.sessions()
        if !sessions.isEmpty {
            saveSessions(sessions)
        }
        if legacy.motorcycle() != nil, motorcycle() == nil {
            Self.logger.error("SwiftData migration did not keep the motorcycle. Will try again next launch.")
            return
        }
        defaults.set(true, forKey: RideReadyStorageKey.didMigrateToSwiftData)
    }

    func motorcycle() -> Motorcycle? {
        read { context in
            try context.fetch(FetchDescriptor<MotorcycleRecord>()).first.map(Self.motorcycle(from:))
        } ?? nil
    }

    func save(_ motorcycle: Motorcycle) {
        write { context in
            let records = try context.fetch(FetchDescriptor<MotorcycleRecord>())
            let record = records.first ?? MotorcycleRecord()
            if records.isEmpty {
                context.insert(record)
            }
            for extra in records.dropFirst() {
                context.delete(extra)
            }
            Self.apply(motorcycle, to: record)
        }
    }

    func motorcyclePhoto() -> Data? {
        read { context in
            try context.fetch(FetchDescriptor<MotorcycleRecord>()).first?.photo
        } ?? nil
    }

    func saveMotorcyclePhoto(_ data: Data?) {
        write { context in
            guard let record = try context.fetch(FetchDescriptor<MotorcycleRecord>()).first else { return }
            record.photo = data
        }
    }

    func activeInspection() -> PreRideInspection? {
        read { context in
            let descriptor = FetchDescriptor<InspectionRecord>(
                predicate: #Predicate { $0.completedAt == nil }
            )
            return try context.fetch(descriptor).first.map(Self.inspection(from:))
        } ?? nil
    }

    func save(_ inspection: PreRideInspection) {
        write { context in
            let inspectionID = inspection.id
            let descriptor = FetchDescriptor<InspectionRecord>(
                predicate: #Predicate { $0.id == inspectionID }
            )
            let record = try context.fetch(descriptor).first ?? InspectionRecord(
                id: inspection.id,
                startedAt: inspection.startedAt,
                motorcycleName: inspection.motorcycle.name,
                finalDriveRaw: inspection.motorcycle.finalDrive.rawValue,
                frontTyrePressurePSI: inspection.motorcycle.frontTyrePressurePSI,
                rearTyrePressurePSI: inspection.motorcycle.rearTyrePressurePSI
            )
            if record.modelContext == nil {
                context.insert(record)
            }
            Self.apply(inspection, to: record)
            record.motorcycle = try context.fetch(FetchDescriptor<MotorcycleRecord>()).first
            Self.replaceFindings(on: record, with: inspection.findings, in: context)
        }
    }

    func completedInspections() -> [PreRideInspection] {
        read { context in
            let descriptor = FetchDescriptor<InspectionRecord>(
                predicate: #Predicate { $0.completedAt != nil },
                sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
            )
            return try context.fetch(descriptor).map(Self.inspection(from:))
        } ?? []
    }

    func streak() -> SafetyStreak {
        read { context in
            guard let record = try context.fetch(FetchDescriptor<SafetyStreakRecord>()).first else {
                return SafetyStreak(consecutiveDays: 0, lastCompletedOn: nil)
            }
            return SafetyStreak(consecutiveDays: record.consecutiveDays, lastCompletedOn: record.lastCompletedOn)
        } ?? SafetyStreak(consecutiveDays: 0, lastCompletedOn: nil)
    }

    func save(_ streak: SafetyStreak) {
        write { context in
            let records = try context.fetch(FetchDescriptor<SafetyStreakRecord>())
            let record = records.first ?? SafetyStreakRecord()
            if records.isEmpty {
                context.insert(record)
            }
            record.consecutiveDays = streak.consecutiveDays
            record.lastCompletedOn = streak.lastCompletedOn
        }
    }

    func activeRide() -> Ride? {
        read { context in
            let descriptor = FetchDescriptor<RideRecord>(
                predicate: #Predicate { $0.endedAt == nil }
            )
            return try context.fetch(descriptor).first.map(Self.ride(from:))
        } ?? nil
    }

    func save(_ ride: Ride) {
        write { context in
            let rideID = ride.id
            let descriptor = FetchDescriptor<RideRecord>(
                predicate: #Predicate { $0.id == rideID }
            )
            let record = try context.fetch(descriptor).first ?? RideRecord(id: ride.id, startedAt: ride.startedAt)
            if record.modelContext == nil {
                context.insert(record)
            }
            record.startedAt = ride.startedAt
            record.endedAt = ride.endedAt
            record.remindAgainAt = ride.remindAgainAt
            Self.replaceStops(on: record, with: ride.stops, in: context)
        }
    }

    func completedRides() -> [Ride] {
        read { context in
            let descriptor = FetchDescriptor<RideRecord>(
                predicate: #Predicate { $0.endedAt != nil },
                sortBy: [SortDescriptor(\.endedAt, order: .reverse)]
            )
            return try context.fetch(descriptor).map(Self.ride(from:))
        } ?? []
    }

    func breakReminderSettings() -> BreakReminderSettings {
        read { context in
            guard let record = try context.fetch(FetchDescriptor<BreakReminderSettingsRecord>()).first else {
                return .standard
            }
            return BreakReminderSettings(isEnabled: record.isEnabled, intervalMinutes: record.intervalMinutes)
        } ?? .standard
    }

    func save(_ settings: BreakReminderSettings) {
        write { context in
            let records = try context.fetch(FetchDescriptor<BreakReminderSettingsRecord>())
            let record = records.first ?? BreakReminderSettingsRecord(
                isEnabled: settings.isEnabled,
                intervalMinutes: settings.intervalMinutes
            )
            if records.isEmpty {
                context.insert(record)
            }
            record.isEnabled = settings.isEnabled
            record.intervalMinutes = settings.intervalMinutes
        }
    }

    func tracks() -> [Track] {
        read { context in
            try context.fetch(FetchDescriptor<TrackRecord>()).map { record in
                Track(
                    id: record.id,
                    name: record.name,
                    location: record.location,
                    lengthMeters: record.lengthMeters,
                    notes: record.notes
                )
            }
        } ?? []
    }

    func saveTracks(_ tracks: [Track]) {
        write { context in
            let existing = try context.fetch(FetchDescriptor<TrackRecord>())
            let incoming = Set(tracks.map(\.id))
            for record in existing where !incoming.contains(record.id) {
                context.delete(record)
            }
            for track in tracks {
                let trackID = track.id
                let descriptor = FetchDescriptor<TrackRecord>(predicate: #Predicate { $0.id == trackID })
                let record = try context.fetch(descriptor).first ?? TrackRecord(id: track.id, name: track.name)
                if record.modelContext == nil {
                    context.insert(record)
                }
                record.name = track.name
                record.location = track.location
                record.lengthMeters = track.lengthMeters
                record.notes = track.notes
            }
        }
    }

    func sessions() -> [Session] {
        read { context in
            try context.fetch(FetchDescriptor<SessionRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)]))
                .map(Self.session(from:))
        } ?? []
    }

    func saveSessions(_ sessions: [Session]) {
        write { context in
            let existing = try context.fetch(FetchDescriptor<SessionRecord>())
            let incoming = Set(sessions.map(\.id))
            for record in existing where !incoming.contains(record.id) {
                context.delete(record)
            }
            for session in sessions {
                let sessionID = session.id
                let descriptor = FetchDescriptor<SessionRecord>(predicate: #Predicate { $0.id == sessionID })
                let record = try context.fetch(descriptor).first ?? SessionRecord(
                    id: session.id,
                    date: session.date,
                    vehicleID: session.vehicleID,
                    trackID: session.trackID,
                    weatherRaw: session.weather.rawValue
                )
                if record.modelContext == nil {
                    context.insert(record)
                }
                record.date = session.date
                record.vehicleID = session.vehicleID
                record.trackID = session.trackID
                record.weatherRaw = session.weather.rawValue
                record.trackCondition = session.trackCondition
                record.setupNotes = session.setupNotes
                Self.replaceLaps(on: record, with: session.laps, in: context)
            }
        }
    }

    func eraseAll() {
        write { context in
            // Fetch-and-delete works in the in-memory store used by tests. A batch
            // delete is not available there, and would leave the rider's data behind.
            try Self.deleteAll(FindingRecord.self, in: context)
            try Self.deleteAll(RideStopRecord.self, in: context)
            try Self.deleteAll(InspectionRecord.self, in: context)
            try Self.deleteAll(RideRecord.self, in: context)
            try Self.deleteAll(MotorcycleRecord.self, in: context)
            try Self.deleteAll(SafetyStreakRecord.self, in: context)
            try Self.deleteAll(BreakReminderSettingsRecord.self, in: context)
            try Self.deleteAll(LapRecord.self, in: context)
            try Self.deleteAll(SessionRecord.self, in: context)
            try Self.deleteAll(TrackRecord.self, in: context)
        }
    }

    private static func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws {
        for model in try context.fetch(FetchDescriptor<T>()) {
            context.delete(model)
        }
    }

    private func read<T>(_ body: (ModelContext) throws -> T) -> T? {
        do {
            return try withContext(body)
        } catch {
            Self.logger.error("Read failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func write(_ body: (ModelContext) throws -> Void) {
        do {
            try withContext { context in
                try body(context)
                try context.save()
            }
            RideReadyWidgetPublisher.publish(from: self)
        } catch {
            Self.logger.error("Save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func withContext<T>(_ body: (ModelContext) throws -> T) throws -> T {
        if Thread.isMainThread {
            return try MainActor.assumeIsolated {
                try body(container.mainContext)
            }
        }
        return try DispatchQueue.main.sync {
            try MainActor.assumeIsolated {
                try body(self.container.mainContext)
            }
        }
    }

    private static func apply(_ motorcycle: Motorcycle, to record: MotorcycleRecord) {
        record.name = motorcycle.name
        record.finalDriveRaw = motorcycle.finalDrive.rawValue
        record.frontTyrePressurePSI = motorcycle.frontTyrePressurePSI
        record.rearTyrePressurePSI = motorcycle.rearTyrePressurePSI
        record.chainSlackMinMillimetres = motorcycle.chainSlackMinMillimetres
        record.chainSlackMaxMillimetres = motorcycle.chainSlackMaxMillimetres
    }

    private static func motorcycle(from record: MotorcycleRecord) -> Motorcycle {
        Motorcycle(
            name: record.name,
            finalDrive: FinalDrive(rawValue: record.finalDriveRaw) ?? .chain,
            frontTyrePressurePSI: record.frontTyrePressurePSI,
            rearTyrePressurePSI: record.rearTyrePressurePSI,
            chainSlackMinMillimetres: record.chainSlackMinMillimetres,
            chainSlackMaxMillimetres: record.chainSlackMaxMillimetres
        )
    }

    private static func apply(_ inspection: PreRideInspection, to record: InspectionRecord) {
        record.startedAt = inspection.startedAt
        record.completedAt = inspection.completedAt
        record.readinessRaw = inspection.readiness?.rawValue
        record.motorcycleName = inspection.motorcycle.name
        record.finalDriveRaw = inspection.motorcycle.finalDrive.rawValue
        record.frontTyrePressurePSI = inspection.motorcycle.frontTyrePressurePSI
        record.rearTyrePressurePSI = inspection.motorcycle.rearTyrePressurePSI
        record.chainSlackMinMillimetres = inspection.motorcycle.chainSlackMinMillimetres
        record.chainSlackMaxMillimetres = inspection.motorcycle.chainSlackMaxMillimetres
    }

    private static func inspection(from record: InspectionRecord) -> PreRideInspection {
        let findings = record.findings
            .sorted { $0.sortIndex < $1.sortIndex }
            .compactMap { row -> InspectionFinding? in
                guard let item = InspectionItem(rawValue: row.itemRaw),
                      let result = InspectionResult(rawValue: row.resultRaw) else {
                    return nil
                }
                return InspectionFinding(item: item, result: result)
            }
        return PreRideInspection(
            id: record.id,
            motorcycle: Motorcycle(
                name: record.motorcycleName,
                finalDrive: FinalDrive(rawValue: record.finalDriveRaw) ?? .chain,
                frontTyrePressurePSI: record.frontTyrePressurePSI,
                rearTyrePressurePSI: record.rearTyrePressurePSI,
                chainSlackMinMillimetres: record.chainSlackMinMillimetres,
                chainSlackMaxMillimetres: record.chainSlackMaxMillimetres
            ),
            startedAt: record.startedAt,
            findings: findings,
            completedAt: record.completedAt,
            readiness: record.readinessRaw.flatMap(RideReadiness.init(rawValue:))
        )
    }

    private static func replaceFindings(
        on record: InspectionRecord,
        with findings: [InspectionFinding],
        in context: ModelContext
    ) {
        for finding in record.findings {
            context.delete(finding)
        }
        record.findings.removeAll()
        for (index, finding) in findings.enumerated() {
            let row = FindingRecord(
                sortIndex: index,
                itemRaw: finding.item.rawValue,
                resultRaw: finding.result.rawValue
            )
            row.inspection = record
            context.insert(row)
        }
    }

    private static func ride(from record: RideRecord) -> Ride {
        Ride(
            id: record.id,
            startedAt: record.startedAt,
            endedAt: record.endedAt,
            stops: record.stops
                .sorted { $0.sortIndex < $1.sortIndex }
                .map { RideStop(startedAt: $0.startedAt, endedAt: $0.endedAt) },
            remindAgainAt: record.remindAgainAt
        )
    }

    private static func session(from record: SessionRecord) -> Session {
        Session(
            id: record.id,
            date: record.date,
            vehicleID: record.vehicleID,
            trackID: record.trackID,
            weather: WeatherCondition(rawValue: record.weatherRaw) ?? .dry,
            trackCondition: record.trackCondition,
            setupNotes: record.setupNotes,
            laps: record.laps
                .sorted { $0.sortIndex < $1.sortIndex }
                .map { Lap(id: $0.id, lapNumber: $0.lapNumber, time: $0.time, notes: $0.notes) }
        )
    }

    private static func replaceLaps(on record: SessionRecord, with laps: [Lap], in context: ModelContext) {
        for lap in record.laps {
            context.delete(lap)
        }
        record.laps.removeAll()
        for (index, lap) in laps.enumerated() {
            let row = LapRecord(sortIndex: index, id: lap.id, lapNumber: lap.lapNumber, time: lap.time, notes: lap.notes)
            row.session = record
            context.insert(row)
        }
    }

    private static func replaceStops(on record: RideRecord, with stops: [RideStop], in context: ModelContext) {
        for stop in record.stops {
            context.delete(stop)
        }
        record.stops.removeAll()
        for (index, stop) in stops.enumerated() {
            let row = RideStopRecord(sortIndex: index, startedAt: stop.startedAt, endedAt: stop.endedAt)
            row.ride = record
            context.insert(row)
        }
    }
}
