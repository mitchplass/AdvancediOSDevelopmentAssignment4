import Foundation

/// Saves whether break reminders are on and how often they come.
///
/// Business Rule: the interval is 30 minutes to 4 hours, in 15-minute steps.
struct SaveBreakReminderSettingsUseCase {
    let store: RideReadyStoring

    func save(_ settings: BreakReminderSettings) throws -> BreakReminderSettings {
        guard BreakReminderSettings.intervalRange.contains(settings.intervalMinutes),
              settings.intervalMinutes % BreakReminderSettings.intervalStep == 0 else {
            throw SaveBreakReminderSettingsError.intervalOutOfRange
        }
        store.save(settings)
        return settings
    }
}

/// Failures when Alex changes the break reminder.
enum SaveBreakReminderSettingsError: LocalizedError, Equatable {
    case intervalOutOfRange

    var errorDescription: String? {
        switch self {
        case .intervalOutOfRange:
            return "Break reminders can be every 30 minutes to 4 hours, in 15-minute steps."
        }
    }
}
