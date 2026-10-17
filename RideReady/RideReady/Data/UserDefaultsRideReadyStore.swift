import Foundation

/// Saves the motorcycle, walk-arounds, and streak in UserDefaults as JSON.
final class UserDefaultsRideReadyStore: RideReadyStoring {
    private enum Key {
        static let motorcycle = "rideReady.motorcycle"
        static let motorcyclePhoto = "rideReady.motorcyclePhoto"
        static let inspections = "rideReady.inspections"
        static let streak = "rideReady.streak"
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

    private func inspections() -> [PreRideInspection] {
        decode([PreRideInspection].self, forKey: Key.inspections) ?? []
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
