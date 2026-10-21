import Foundation

/// A small, versioned read model. The extension never reads the app's database.
struct RideReadyWidgetSnapshot: Codable, Equatable, Sendable {
    var version = 2
    var motorcycleName: String?
    var hasActiveInspection = false
    var checkedItems = 0
    var requiredItems = 0
    var needsAttention = false
    var lastCompletedAt: Date?
    var lastCheckPassed = false
    var flaggedItems: [String] = []

    enum Status: Equatable {
        case setup, notChecked, inProgress, needsAttention, checked
    }

    func status(at date: Date, calendar: Calendar = .current) -> Status {
        guard motorcycleName != nil else { return .setup }
        if needsAttention { return .needsAttention }
        if hasActiveInspection { return .inProgress }
        if lastCheckPassed, let lastCompletedAt,
           lastCompletedAt <= date,
           calendar.isDate(lastCompletedAt, inSameDayAs: date) {
            return .checked
        }
        return .notChecked
    }

    /// Precompute the expiry entry, even if iOS delays the next provider reload.
    static func nextDay(after date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))
            ?? date.addingTimeInterval(24 * 60 * 60)
    }

    static let sample = RideReadyWidgetSnapshot(
        motorcycleName: "Yamaha MT-07",
        hasActiveInspection: true,
        checkedItems: 2,
        requiredItems: 4
    )
}

/// Uses the timeline entry date, so precomputed midnight entries say Yesterday correctly.
enum WidgetLastCheckText {
    static func string(for date: Date?, relativeTo reference: Date,
                       calendar: Calendar = .current, locale: Locale = .current) -> String {
        guard let date else { return "No check for this setup" }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.timeStyle = .short
        let time = formatter.string(from: date)
        if calendar.isDate(date, inSameDayAs: reference) { return "Today, \(time)" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: reference),
           calendar.isDate(date, inSameDayAs: yesterday) { return "Yesterday, \(time)" }
        formatter.setLocalizedDateFormatFromTemplate("d MMM yyyy")
        return "\(formatter.string(from: date)), \(time)"
    }
}

enum RideReadyWidgetConfiguration {
    static let kind = "RideReadyPreRideWidget"
    static let checkURL = URL(string: "rideready://check")!
    static let homeURL = URL(string: "rideready://home")!

    enum Destination: Equatable { case check, home }

    static func destination(for url: URL) -> Destination? {
        guard url.scheme?.lowercased() == "rideready",
              url.user == nil, url.password == nil, url.port == nil,
              url.path.isEmpty || url.path == "/",
              url.query == nil, url.fragment == nil else { return nil }
        switch url.host?.lowercased() {
        case "check": return .check
        case "home": return .home
        default: return nil
        }
    }
}
