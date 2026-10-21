import Foundation

/// Removes the motorcycle, photo, walk-arounds, rides, journal, lap times, streak,
/// and reminder settings from this iPhone. Appearance is left as the rider set it.
struct EraseRideDataUseCase {
    let store: RideReadyStoring
    let journal: RideJournalRepository
    var preferences: UserDefaults = .standard

    func erase() {
        store.eraseAll()
        try? journal.eraseAll()
        // The previous UserDefaults store may still hold a copy from before SwiftData.
        if !(store is UserDefaultsRideReadyStore) {
            UserDefaultsRideReadyStore(defaults: preferences).eraseAll()
        }
        preferences.set(true, forKey: RideReadyStorageKey.suppressSampleMotorcycle)
    }
}
