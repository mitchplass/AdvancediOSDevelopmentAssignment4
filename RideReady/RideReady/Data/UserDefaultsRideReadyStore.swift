import Foundation

/// Saves the motorcycle, walk-arounds, streak, rides, break reminder settings,
/// and the lap timer's tracks and sessions in UserDefaults as JSON.
final class UserDefaultsRideReadyStore: RideReadyStoring {
    private enum Key {
        static let motorcycle = "rideReady.motorcycle"
        static let motorcyclePhoto = "rideReady.motorcyclePhoto"
        static let inspections = "rideReady.inspections"
        static let streak = "rideReady.streak"
        static let rides = "rideReady.rides"
        static let breakReminderSettings = "rideReady.breakReminderSettings"
        static let tracks = "rideReady.tracks"
        static let sessions = "rideReady.sessions"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func motorcycle() -> Motorcycle? {
        decode(Motorcycle.self, forKey: Key.motorcycle)
    }

    func save(_ motorcycle: Motorcycle) {
        encode(motorcycle, forKey: Key.motorcycle)
    }

    func motorcyclePhoto() -> Data? {
        defaults.data(forKey: Key.motorcyclePhoto)
    }

    func saveMotorcyclePhoto(_ data: Data?) {
        if let data {
            defaults.set(data, forKey: Key.motorcyclePhoto)
        } else {
            defaults.removeObject(forKey: Key.motorcyclePhoto)
        }
    }

    func activeInspection() -> PreRideInspection? {
        inspections().first { $0.completedAt == nil }
    }

    func save(_ inspection: PreRideInspection) {
        var inspections = inspections()
        if let index = inspections.firstIndex(where: { $0.id == inspection.id }) {
            inspections[index] = inspection
        } else {
            inspections.append(inspection)
        }
        encode(inspections, forKey: Key.inspections)
    }

    func completedInspections() -> [PreRideInspection] {
        inspections()
            .filter { $0.completedAt != nil }
            .sorted { lhs, rhs in
                (lhs.completedAt ?? .distantPast) > (rhs.completedAt ?? .distantPast)
            }
    }

    func streak() -> SafetyStreak {
        decode(SafetyStreak.self, forKey: Key.streak)
            ?? SafetyStreak(consecutiveDays: 0, lastCompletedOn: nil)
    }

    func save(_ streak: SafetyStreak) {
        encode(streak, forKey: Key.streak)
    }

    func activeRide() -> Ride? {
        rides().first { $0.endedAt == nil }
    }

    func save(_ ride: Ride) {
        var rides = rides()
        if let index = rides.firstIndex(where: { $0.id == ride.id }) {
            rides[index] = ride
        } else {
            rides.append(ride)
        }
        encode(rides, forKey: Key.rides)
    }

    func completedRides() -> [Ride] {
        rides()
            .filter { $0.endedAt != nil }
            .sorted { lhs, rhs in
                (lhs.endedAt ?? .distantPast) > (rhs.endedAt ?? .distantPast)
            }
    }

    func breakReminderSettings() -> BreakReminderSettings {
        decode(BreakReminderSettings.self, forKey: Key.breakReminderSettings) ?? .standard
    }

    func save(_ settings: BreakReminderSettings) {
        encode(settings, forKey: Key.breakReminderSettings)
    }

    func eraseAll() {
        defaults.removeObject(forKey: Key.motorcycle)
        defaults.removeObject(forKey: Key.motorcyclePhoto)
        defaults.removeObject(forKey: Key.inspections)
        defaults.removeObject(forKey: Key.streak)
        defaults.removeObject(forKey: Key.rides)
        defaults.removeObject(forKey: Key.breakReminderSettings)
        defaults.removeObject(forKey: Key.tracks)
        defaults.removeObject(forKey: Key.sessions)
    }

    func tracks() -> [Track] {
        decode([Track].self, forKey: Key.tracks) ?? []
    }

    func saveTracks(_ tracks: [Track]) {
        encode(tracks, forKey: Key.tracks)
    }

    func sessions() -> [Session] {
        decode([Session].self, forKey: Key.sessions) ?? []
    }

    func saveSessions(_ sessions: [Session]) {
        encode(sessions, forKey: Key.sessions)
    }

    private func inspections() -> [PreRideInspection] {
        decode([PreRideInspection].self, forKey: Key.inspections) ?? []
    }

    private func rides() -> [Ride] {
        decode([Ride].self, forKey: Key.rides) ?? []
    }

    private func encode<T: Encodable>(_ value: T, forKey key: String) {
        if let data = try? encoder.encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(type, from: data)
    }
}
