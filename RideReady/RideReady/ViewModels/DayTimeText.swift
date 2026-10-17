import Foundation

/// When something happened, for lists and status lines.
enum DayTimeText {
    /// "Today, 11:19 pm", "Yesterday, 7:40 am" or "Fri 16 Oct, 7:40 am". Pass
    /// `capitalized: false` mid-sentence ("Last check: today, 11:19 pm").
    static func string(for date: Date, capitalized: Bool = true) -> String {
        let calendar = Calendar.current
        let day: String
        if calendar.isDateInToday(date) {
            day = capitalized ? "Today" : "today"
        } else if calendar.isDateInYesterday(date) {
            day = capitalized ? "Yesterday" : "yesterday"
        } else {
            day = dayFormatter.string(from: date)
        }
        return "\(day), \(time(date))"
    }

    /// "7:40 am".
    static func time(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEdMMM")
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}
